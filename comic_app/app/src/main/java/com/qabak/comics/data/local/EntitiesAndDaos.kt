package com.qabak.comics.data.local

import android.content.Context
import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import com.qabak.comics.model.BookmarkItem
import com.qabak.comics.model.ComicBook
import com.qabak.comics.model.ComicSourceType
import com.qabak.comics.model.ReadingMode
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "comics")
data class ComicEntity(
    @PrimaryKey val id: String,
    val titleFa: String,
    val titleEn: String,
    val seriesFa: String,
    val seriesEn: String,
    val authorFa: String,
    val authorEn: String,
    val genreFa: String,
    val genreEn: String,
    val descriptionFa: String,
    val descriptionEn: String,
    val sourceType: String,
    val sourcePath: String,
    val coverPath: String,
    val accentHex: String,
    val pageCount: Int,
    val currentPage: Int,
    val isFavorite: Boolean,
    val isCompleted: Boolean,
    val preferredMode: String,
    val addedAt: Long,
    val lastReadAt: Long
) {
    fun toDomain(): ComicBook = ComicBook(
        id = id,
        titleFa = titleFa,
        titleEn = titleEn,
        seriesFa = seriesFa,
        seriesEn = seriesEn,
        authorFa = authorFa,
        authorEn = authorEn,
        genreFa = genreFa,
        genreEn = genreEn,
        descriptionFa = descriptionFa,
        descriptionEn = descriptionEn,
        sourceType = runCatching { ComicSourceType.valueOf(sourceType) }.getOrDefault(ComicSourceType.CBZ),
        sourcePath = sourcePath,
        coverPath = coverPath,
        accentHex = accentHex,
        pageCount = pageCount,
        currentPage = currentPage.coerceIn(0, (pageCount - 1).coerceAtLeast(0)),
        isFavorite = isFavorite,
        isCompleted = isCompleted,
        preferredMode = runCatching { ReadingMode.valueOf(preferredMode) }.getOrDefault(ReadingMode.PAGED_RTL),
        addedAt = addedAt,
        lastReadAt = lastReadAt
    )
}

@Entity(
    tableName = "bookmarks",
    foreignKeys = [
        ForeignKey(
            entity = ComicEntity::class,
            parentColumns = ["id"],
            childColumns = ["comicId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index(value = ["comicId"]),
        Index(value = ["comicId", "pageIndex"], unique = true)
    ]
)
data class BookmarkEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val comicId: String,
    val pageIndex: Int,
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

data class BookmarkJoinedRow(
    val id: Long,
    val comicId: String,
    val pageIndex: Int,
    val note: String,
    val createdAt: Long,
    @ColumnInfo(name = "titleFa") val comicTitleFa: String,
    @ColumnInfo(name = "titleEn") val comicTitleEn: String,
    @ColumnInfo(name = "sourceType") val comicSourceType: String,
    @ColumnInfo(name = "sourcePath") val comicSourcePath: String,
    @ColumnInfo(name = "coverPath") val comicCoverPath: String,
    @ColumnInfo(name = "pageCount") val comicPageCount: Int
) {
    fun toDomain(): BookmarkItem = BookmarkItem(
        id = id,
        comicId = comicId,
        comicTitleFa = comicTitleFa,
        comicTitleEn = comicTitleEn,
        comicSourceType = runCatching { ComicSourceType.valueOf(comicSourceType) }.getOrDefault(ComicSourceType.CBZ),
        comicSourcePath = comicSourcePath,
        comicCoverPath = comicCoverPath,
        comicPageCount = comicPageCount,
        pageIndex = pageIndex,
        note = note,
        createdAt = createdAt
    )
}

@Dao
interface ComicDao {
    @Query("SELECT * FROM comics ORDER BY CASE WHEN lastReadAt > 0 THEN 0 ELSE 1 END, lastReadAt DESC, addedAt DESC")
    fun observeAllComics(): Flow<List<ComicEntity>>

    @Query("SELECT * FROM comics WHERE id = :id LIMIT 1")
    fun observeComicById(id: String): Flow<ComicEntity?>

    @Query("SELECT * FROM comics WHERE id = :id LIMIT 1")
    suspend fun getComicById(id: String): ComicEntity?

    @Query("SELECT * FROM comics")
    suspend fun getAllComicsOnce(): List<ComicEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertComic(comic: ComicEntity)

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertComicIfAbsent(comic: ComicEntity)

    @Query("UPDATE comics SET currentPage = :page, lastReadAt = :timestamp, isCompleted = :completed WHERE id = :id")
    suspend fun updateProgress(id: String, page: Int, timestamp: Long, completed: Boolean)

    @Query("UPDATE comics SET isFavorite = :favorite WHERE id = :id")
    suspend fun updateFavorite(id: String, favorite: Boolean)

    @Query("UPDATE comics SET isCompleted = :completed, currentPage = :page, lastReadAt = :timestamp WHERE id = :id")
    suspend fun updateCompleted(id: String, completed: Boolean, page: Int, timestamp: Long)

    @Query("UPDATE comics SET preferredMode = :mode WHERE id = :id")
    suspend fun updatePreferredMode(id: String, mode: String)

    @Query("DELETE FROM comics WHERE id = :id")
    suspend fun deleteComic(id: String)
}

@Dao
interface BookmarkDao {
    @Query(
        """
        SELECT b.id, b.comicId, b.pageIndex, b.note, b.createdAt,
               c.titleFa, c.titleEn, c.sourceType, c.sourcePath, c.coverPath, c.pageCount
        FROM bookmarks b
        INNER JOIN comics c ON c.id = b.comicId
        ORDER BY b.createdAt DESC
        """
    )
    fun observeAllBookmarks(): Flow<List<BookmarkJoinedRow>>

    @Query(
        """
        SELECT b.id, b.comicId, b.pageIndex, b.note, b.createdAt,
               c.titleFa, c.titleEn, c.sourceType, c.sourcePath, c.coverPath, c.pageCount
        FROM bookmarks b
        INNER JOIN comics c ON c.id = b.comicId
        WHERE b.comicId = :comicId
        ORDER BY b.pageIndex ASC
        """
    )
    fun observeBookmarksForComic(comicId: String): Flow<List<BookmarkJoinedRow>>

    @Query("SELECT * FROM bookmarks WHERE comicId = :comicId AND pageIndex = :pageIndex LIMIT 1")
    suspend fun getBookmark(comicId: String, pageIndex: Int): BookmarkEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertBookmark(bookmark: BookmarkEntity): Long

    @Query("UPDATE bookmarks SET note = :note WHERE id = :id")
    suspend fun updateNote(id: Long, note: String)

    @Query("DELETE FROM bookmarks WHERE comicId = :comicId AND pageIndex = :pageIndex")
    suspend fun deleteBookmarkAt(comicId: String, pageIndex: Int)

    @Query("DELETE FROM bookmarks WHERE id = :id")
    suspend fun deleteBookmarkById(id: Long)
}

@Database(
    entities = [ComicEntity::class, BookmarkEntity::class],
    version = 1,
    exportSchema = false
)
abstract class QabakDatabase : RoomDatabase() {
    abstract fun comicDao(): ComicDao
    abstract fun bookmarkDao(): BookmarkDao

    companion object {
        @Volatile
        private var instance: QabakDatabase? = null

        fun getInstance(context: Context): QabakDatabase {
            return instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    QabakDatabase::class.java,
                    "qabak_comics.db"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { instance = it }
            }
        }
    }
}
