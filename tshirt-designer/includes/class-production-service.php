<?php
/**
 * Production file operations: generation, regeneration, retry, downloads.
 *
 * Sits between Production_Manager (job lifecycle) and Production_Renderer
 * (pixels). Its single most important rule: every render is driven by the
 * IMMUTABLE ORDER SNAPSHOT, never by the live catalogue (§17). Changing a
 * model, a print area or a price after purchase must not alter what ships.
 *
 * @package TShirtDesigner
 */

declare( strict_types=1 );

namespace TShirtDesigner;

defined( 'ABSPATH' ) || exit;

final class Production_Service {

	public function __construct( private Plugin $plugin ) {}

	/**
	 * Render (or reuse) the production files for a job.
	 *
	 * §49: an existing, readable, non-empty file is reused unless $force.
	 *
	 * @return array{ok:bool, files:array<int, array<string,mixed>>, errors:string[]}
	 */
	public function generate( int $job_id, bool $force = false, int $user_id = 0, string $reason = '' ): array {
		$job = $this->plugin->production_jobs->get( $job_id );
		if ( null === $job ) {
			return array( 'ok' => false, 'files' => array(), 'errors' => array( __( 'Production job not found.', 'tshirt-designer' ) ) );
		}

		$snapshot = $this->plugin->production_jobs->snapshot( $job_id );
		if ( null === $snapshot ) {
			$msg = __( 'This job has no stored design snapshot, so no print files can be produced.', 'tshirt-designer' );
			$this->plugin->production_jobs->mark_failed( $job_id, $msg, $user_id );
			return array( 'ok' => false, 'files' => array(), 'errors' => array( $msg ) );
		}

		$result = $this->plugin->production->generate(
			$snapshot,
			(int) $job['order_id'],
			(int) $job['order_item_id'],
			$force,
			$job_id
		);

		if ( $result['ok'] ) {
			$this->plugin->production_jobs->record_event(
				$job_id,
				$force ? Production_Manager::EVENT_REGENERATE : Production_Manager::EVENT_RENDER,
				'',
				'',
				$user_id,
				$reason,
				array( 'files' => count( $result['files'] ) )
			);
			do_action( 'td_production_file_generated', $job_id, $result['files'] );
		} else {
			// §22: never fail silently — flag the job and keep the detail.
			$this->plugin->production_jobs->mark_failed(
				$job_id,
				implode( ' ', $result['errors'] ),
				$user_id
			);
		}

		return $result;
	}

	/**
	 * Regenerate every file for a job from the purchased snapshot (§17/§18).
	 *
	 * @return array{ok:bool, files:array<int, array<string,mixed>>, errors:string[]}
	 */
	public function regenerate( int $job_id, int $user_id = 0, string $reason = '' ): array {
		$reason = trim( $reason );
		if ( '' === $reason ) {
			$reason = __( 'Manual regeneration.', 'tshirt-designer' );
		}
		return $this->generate( $job_id, true, $user_id, $reason );
	}

	/**
	 * Retry a failed job (§23): re-render from the snapshot and, if that works,
	 * put the job back into the queue.
	 *
	 * @return array{ok:bool, files:array<int, array<string,mixed>>, errors:string[]}
	 */
	public function retry( int $job_id, int $user_id = 0, string $reason = '' ): array {
		$job = $this->plugin->production_jobs->get( $job_id );
		if ( null === $job ) {
			return array( 'ok' => false, 'files' => array(), 'errors' => array( __( 'Production job not found.', 'tshirt-designer' ) ) );
		}

		$this->plugin->production_jobs->record_event(
			$job_id,
			Production_Manager::EVENT_RETRY,
			(string) $job['status'],
			'',
			$user_id,
			$reason
		);

		$result = $this->generate( $job_id, true, $user_id, $reason ?: __( 'Retry after failure.', 'tshirt-designer' ) );

		// A successful retry lifts the job out of the error state.
		if ( $result['ok'] && Production_Status::FAILED === (string) $job['status'] ) {
			$this->plugin->production_jobs->transition(
				$job_id,
				Production_Status::READY,
				$user_id,
				__( 'Recovered by retry.', 'tshirt-designer' )
			);
		}

		return $result;
	}

	/**
	 * Files belonging to a job.
	 *
	 * @return array<int, array<string, mixed>>
	 */
	public function files( int $job_id ): array {
		$job = $this->plugin->production_jobs->get( $job_id );
		if ( null === $job ) {
			return array();
		}
		return $this->plugin->production->for_order( (int) $job['order_id'], (int) $job['order_item_id'] );
	}

	/**
	 * Build a ZIP of a job's files (§15).
	 *
	 * @return array{path:string, name:string, count:int}|null
	 */
	public function zip( int $job_id ): ?array {
		$job = $this->plugin->production_jobs->get( $job_id );
		if ( null === $job ) {
			return null;
		}
		return $this->plugin->production->build_zip( (int) $job['order_id'], (int) $job['order_item_id'] );
	}

	// ------------------------------------------------------------ downloads

	/**
	 * Authorise and resolve a production file for download (§31).
	 *
	 * The chain is deliberately: capability -> job exists -> file belongs to
	 * that job -> path is inside our storage dir -> file really exists. A file
	 * ID alone is never enough, so production files are not IDOR-able.
	 *
	 * @return array{ok:bool, error?:string, path?:string, name?:string, mime?:string}
	 */
	public function authorise_file( int $file_id, int $job_id = 0 ): array {
		if ( ! Production_Manager::can_manage() ) {
			return array( 'ok' => false, 'error' => __( 'You are not allowed to download production files.', 'tshirt-designer' ) );
		}

		$file = $this->plugin->production->get_file( $file_id );
		if ( null === $file ) {
			return array( 'ok' => false, 'error' => __( 'That production file does not exist.', 'tshirt-designer' ) );
		}

		if ( $job_id > 0 ) {
			$job = $this->plugin->production_jobs->get( $job_id );
			if ( null === $job
				|| (int) $job['order_id'] !== (int) $file['order_id']
				|| (int) $job['order_item_id'] !== (int) $file['order_item_id'] ) {
				return array( 'ok' => false, 'error' => __( 'That file does not belong to this production job.', 'tshirt-designer' ) );
			}
		}

		$storage = $this->plugin->production->storage_dir();
		if ( null === $storage ) {
			return array( 'ok' => false, 'error' => __( 'The production directory is unavailable.', 'tshirt-designer' ) );
		}

		$path = (string) $file['file_path'];
		$real = '' !== $path ? realpath( $path ) : false;
		$root = realpath( $storage['dir'] );
		if ( false === $real || false === $root || ! is_file( $real ) ) {
			return array( 'ok' => false, 'error' => __( 'The production file is missing. Regenerate it and try again.', 'tshirt-designer' ) );
		}
		// Containment: block traversal / symlink escapes out of the store.
		if ( ! str_starts_with( $real, $root . DIRECTORY_SEPARATOR ) ) {
			return array( 'ok' => false, 'error' => __( 'That file is outside the production directory.', 'tshirt-designer' ) );
		}

		return array(
			'ok'   => true,
			'path' => $real,
			'name' => basename( $real ),
			'mime' => (string) ( $file['mime_type'] ?: 'image/png' ),
		);
	}

	/**
	 * Stream a file to the browser. Only ever called after authorise_file().
	 */
	public function stream( string $path, string $name, string $mime ): void {
		// Flat, sanitised download name — never a path.
		$name = preg_replace( '/[^A-Za-z0-9._-]/', '-', basename( $name ) ) ?? 'production-file';

		nocache_headers();
		header( 'Content-Type: ' . $mime );
		header( 'Content-Disposition: attachment; filename="' . $name . '"' );
		header( 'Content-Length: ' . (string) filesize( $path ) );
		header( 'X-Content-Type-Options: nosniff' );
		// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_readfile
		readfile( $path );
	}
}
