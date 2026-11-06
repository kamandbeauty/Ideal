package com.motionshot.app.motion

import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File

/**
 * Writes the MP4.
 *
 * Ordering rules that matter for player compatibility:
 *  * the **video track is added first** (some OEM players mis-detect fps when
 *    audio is first)
 *  * samples for both tracks must be written in non-decreasing presentation
 *    time per track, so the renderer interleaves them by timestamp
 *  * `stop()` is only called on success; on any failure the partially written
 *    file is deleted so the user can never end up with a corrupt video that
 *    looks like a real export
 */
class MediaMuxerManager(private val outputPath: String) {

    class MuxerException(message: String, cause: Throwable? = null) : Exception(message, cause)

    private var muxer: MediaMuxer? = null
    private var videoTrack = -1
    private var audioTrack = -1
    private var started = false
    private var videoSamples = 0L
    private var audioSamples = 0L
    private var lastVideoPts = -1L
    private var lastAudioPts = -1L
    private var finalized = false

    val videoSampleCount: Long get() = videoSamples
    val audioSampleCount: Long get() = audioSamples

    /** Adds the video track. Must be the first track added. */
    fun addVideoTrack(format: MediaFormat): Int {
        if (started) throw MuxerException("cannot add tracks after muxing started")
        val m = ensureMuxer()
        videoTrack = m.addTrack(format)
        Log.i(TAG, "video track $videoTrack: $format")
        return videoTrack
    }

    /** Adds the optional audio track, after the video track. */
    fun addAudioTrack(format: MediaFormat): Int {
        if (started) throw MuxerException("cannot add tracks after muxing started")
        val m = ensureMuxer()
        audioTrack = m.addTrack(format)
        Log.i(TAG, "audio track $audioTrack: $format")
        return audioTrack
    }

    /** Begins muxing. Must be called after every track has been added. */
    fun startIfReady() {
        if (started) return
        if (videoTrack < 0) throw MuxerException("cannot start without a video track")
        try {
            muxer?.start()
        } catch (e: Exception) {
            throw MuxerException("muxer.start failed", e)
        }
        started = true
    }

    /** True once the file is open and tracks are registered. */
    val isStarted: Boolean get() = started

    fun writeVideo(bytes: ByteArray, ptsUs: Long, flags: Int) {
        write(videoTrack, bytes, ptsUs, flags)
        videoSamples++
    }

    fun writeAudio(bytes: ByteArray, ptsUs: Long, flags: Int) {
        write(audioTrack, bytes, ptsUs, flags)
        audioSamples++
    }

    private fun write(track: Int, bytes: ByteArray, ptsUs: Long, flags: Int) {
        val m = muxer ?: throw MuxerException("muxer not initialised")
        if (!started) startIfReady()
        if (track < 0) throw MuxerException("track not added")
        try {
            val buffer = java.nio.ByteBuffer.wrap(bytes)
            val info = MediaCodec.BufferInfo().apply {
                set(0, bytes.size, ptsUs, flags)
            }
            m.writeSampleData(track, buffer, info)
        } catch (e: Exception) {
            throw MuxerException("writeSampleData failed (track=$track pts=$ptsUs)", e)
        }
        if (track == videoTrack) lastVideoPts = ptsUs else lastAudioPts = ptsUs
    }

    /**
     * Flushes and closes the file. Returns true only when a usable MP4 exists.
     * On failure the file is removed.
     */
    fun finish(): Boolean {
        if (finalized) return true
        finalized = true
        var ok = true
        try {
            muxer?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "muxer stop failed: ${e.message}")
            ok = false
        }
        try {
            muxer?.release()
        } catch (e: Exception) {
            Log.e(TAG, "muxer release failed: ${e.message}")
            ok = false
        }
        muxer = null
        val file = File(outputPath)
        if (!ok || !file.exists() || file.length() < 4096 || videoSamples == 0L) {
            file.delete()
            return false
        }
        val audioOk = audioTrack < 0 || audioSamples > 0
        if (!audioOk) {
            // Video is valid but audio is not: keep the video, report the fact.
            Log.w(TAG, "audio track present but empty; video kept")
        }
        Log.i(
            TAG,
            "muxed ${file.length() / 1024}KB, video=$videoSamples audio=$audioSamples",
        )
        return true
    }

    /**
     * Releases the underlying MediaMuxer without touching the file.
     * No-op after [finish]/[abort]; used as a safety net on failure paths
     * where the muxer was started but never finalized (fd leak).
     */
    fun releaseQuietly() {
        val m = muxer ?: return
        muxer = null
        try {
            m.release()
        } catch (e: Exception) {
            Log.d(TAG, "muxer release: ${e.message}")
        }
    }

    /** Aborts and deletes any partial output. Safe to call twice. */
    fun abort() {
        finalized = true
        started = false
        try {
            muxer?.release()
        } catch (ignored: Exception) {
        }
        muxer = null
        val file = File(outputPath)
        if (file.exists()) file.delete()
        Log.w(TAG, "aborted, partial file removed")
    }

    private fun ensureMuxer(): MediaMuxer {
        var m = muxer
        if (m == null) {
            val file = File(outputPath)
            file.parentFile?.mkdirs()
            if (file.exists()) file.delete()
            m = try {
                MediaMuxer(
                    outputPath,
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4,
                )
            } catch (e: Exception) {
                throw MuxerException("cannot create muxer for $outputPath", e)
            }
            muxer = m
        }
        return m
    }

    companion object {
        private const val TAG = "MediaMuxerManager"
    }
}
