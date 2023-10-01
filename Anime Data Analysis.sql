--Looking at the data as a whole
SELECT *
FROM Anime..AnimeData;

---------------------------------------------------------------------------------

--Looking for duplicates
SELECT title, count(*) as duplicate_count
FROM Anime..AnimeData
GROUP BY title
HAVING COUNT(*) > 1;

SELECT anime_id, count(*) as duplicate_count
FROM Anime..AnimeData
GROUP BY anime_id
HAVING COUNT(*) > 1;

---------------------------------------------------------------------------------

--Removing unnecessary columns
ALTER TABLE Anime..AnimeData
DROP COLUMN main_pic
			, pics
			, clubs
			, score_01_count
			, score_02_count
			, score_03_count
			, score_04_count
			, score_05_count
			, score_06_count
			, score_07_count
			, score_08_count
			, score_09_count
			, score_10_count
			, total_count
			, start_date
			, end_date
			, members_count
			, source_type

---------------------------------------------------------------------------------

--Dealing with Date and Time formatting
---Formatting Start Date
SELECT CAST(start_date as DATE) AS start_date_formatted
FROM Anime..AnimeData;

ALTER TABLE Anime..AnimeData
ADD  start_date_formatted DATE;

UPDATE Anime..AnimeData
SET start_date_formatted = CAST(start_date as DATE);

---Formatting End Date
SELECT CAST(end_date as DATE) AS end_date_formatted
FROM Anime..AnimeData;

ALTER TABLE Anime..AnimeData
ADD  end_date_formatted DATE;

UPDATE Anime..AnimeData
SET end_date_formatted = CAST(end_date as DATE);

---Formatting the Season column to show ONLY the season
UPDATE Anime..AnimeData
SET season = SUBSTRING(Season, 1, CHARINDEX(' ', Season) - 1)
WHERE CHARINDEX(' ', season) > 0;

---------------------------------------------------------------------------------

--Dealing with NULL values
---Removing rows where SCORE = NULL and STATUS = finished_airing
---- this gives no meaningful info such that the score, popularity, and favorites are extremely low or 0, considering they finished airing
SELECT *
FROM Anime..AnimeData
WHERE score IS NULL AND status = 'Finished Airing'
ORDER BY favorites_count DESC;

DELETE FROM Anime..AnimeData
WHERE score IS NULL AND status = 'Finished Airing';

--Doing the same thing with animes currently airing, but only where favorities is 0
SELECT *
FROM Anime..AnimeData
WHERE score IS NULL AND status = 'Currently Airing' AND favorites_count = 0;

DELETE FROM Anime..AnimeData
WHERE score IS NULL AND status = 'Currently Airing' AND favorites_count = 0;

--Get rid of not yet aired where favorities is 0 - not really relevant or meaningful
SELECT *
FROM Anime..AnimeData
WHERE score IS NULL AND status = 'Not yet Aired' AND favorites_count = 0;

DELETE FROM Anime..AnimeData
WHERE score IS NULL AND status = 'Not yet Aired' AND favorites_count = 0;

--Fill in NULL values in season column based on start date column
UPDATE Anime..AnimeData
SET season = CASE
    WHEN MONTH(start_date_formatted) IN (1, 2, 3) THEN 'Winter'
    WHEN MONTH(start_date_formatted) IN (4, 5, 6) THEN 'Spring'
    WHEN MONTH(start_date_formatted) IN (7, 8, 9) THEN 'Summer'
    WHEN MONTH(start_date_formatted) IN (10, 11, 12) THEN 'Fall'
    ELSE NULL
END
WHERE season IS NULL;

---------------------------------------------------------------------------------

--What are the top 10 highest rated anime?
SELECT TOP 10 title, score
FROM Anime..AnimeData
ORDER BY score DESC;

--Breaking it down by Type
---Top rated Movie
SELECT TOP 10 title, score, type
FROM Anime..AnimeData
WHERE type = 'movie' AND score IS NOT NULL
ORDER BY score DESC;

---Top rated TV show
SELECT TOP 10 title, score, type
FROM Anime..AnimeData
WHERE type = 'TV' AND score IS NOT NULL
ORDER BY score DESC;

---------------------------------------------------------------------------------

--Number of animes airing based on Season of the year (most saturated season of the year for new animes)
SELECT season, COUNT(*) AS num_animes_aired, ROUND((COUNT(*) * 100) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM Anime..AnimeData
WHERE season IS NOT NULL
GROUP BY season
ORDER BY num_animes_aired DESC;

---------------------------------------------------------------------------------

--What is the most popular genre?
SELECT TOP 1 Genre, COUNT(*) AS GenreCount
FROM (
    SELECT value AS Genre
    FROM Anime..AnimeData
    CROSS APPLY STRING_SPLIT(genres, '|')
    WHERE genres IS NOT NULL
) AS GenreSplit
GROUP BY Genre
ORDER BY GenreCount DESC;

---------------------------------------------------------------------------------

--What is the most popular genre in the top 10 rated anime?
WITH Top10Anime AS (
    SELECT TOP 10 title, score, genres
    FROM Anime..AnimeData
    WHERE score IS NOT NULL
    ORDER BY score DESC
)

SELECT TOP 1 Genre, COUNT(*) AS GenreCount
FROM (
    SELECT s.value AS Genre
    FROM Top10Anime a
    CROSS APPLY STRING_SPLIT(a.genres, '|') AS s
    WHERE a.genres IS NOT NULL
) AS Top10Genres
GROUP BY Genre
ORDER BY GenreCount DESC;

---------------------------------------------------------------------------------

--Looking at the trends in genre popularity over different seasons in the year
SELECT
    season AS Season,
    s.value AS Genre,
    COUNT(*) AS AnimeCount
FROM Anime..AnimeData a
CROSS APPLY STRING_SPLIT(a.genres, '|') AS s
WHERE a.genres IS NOT NULL AND season IS NOT NULL
GROUP BY season, s.value
ORDER BY season, AnimeCount DESC;

---------------------------------------------------------------------------------

--Genre popularity over 'all time' - 1917 - 2023
SELECT
    a.season,
    YEAR(a.start_date_formatted) AS Year,
    s.value AS Genre,
    COUNT(*) AS AnimeCount
FROM Anime..AnimeData a
CROSS APPLY STRING_SPLIT(a.genres, '|') AS s
WHERE a.genres IS NOT NULL AND a.start_date_formatted IS NOT NULL
GROUP BY a.season, YEAR(a.start_date_formatted), s.value
ORDER BY a.season, Year, AnimeCount DESC;

---------------------------------------------------------------------------------

--Genres gaining popularity by looking at animes that are not yet aired
SELECT
    s.value AS Genre,
    COUNT(*) AS AnimeCount
FROM Anime..AnimeData a
CROSS APPLY STRING_SPLIT(a.genres, '|') AS s
WHERE a.genres IS NOT NULL
    AND a.status = 'Not Yet Aired'
GROUP BY s.value
ORDER BY AnimeCount DESC;

---------------------------------------------------------------------------------

--Which studio has produced the highest number of animes?
SELECT TOP 1 Studio, COUNT(*) AS StudioCount
FROM (
    SELECT value AS Studio
    FROM Anime..AnimeData
    CROSS APPLY STRING_SPLIT(studios, '|')
    WHERE studios IS NOT NULL
) AS StudioSplit
GROUP BY Studio
ORDER BY StudioCount DESC;

---------------------------------------------------------------------------------

--What is the most popular studio in the top 50 rated anime?
WITH Top50Anime AS (
    SELECT TOP 50 title, score, studios
    FROM Anime..AnimeData
    WHERE score IS NOT NULL
    ORDER BY score DESC
)

SELECT TOP 1 Studio, COUNT(*) AS StudioCount
FROM (
    SELECT s.value AS Studio
    FROM Top50Anime a
    CROSS APPLY STRING_SPLIT(a.studios, '|') AS s
    WHERE a.studios IS NOT NULL
) AS Top10Studios
GROUP BY Studio
ORDER BY StudioCount DESC;

---------------------------------------------------------------------------------

--Finding which studio has the highest average ratings
WITH StudioData AS (
    SELECT
        s.value AS Studio,
        ROUND(CAST(score AS decimal(5, 2)), 2) AS Rating
    FROM Anime..AnimeData a
    CROSS APPLY STRING_SPLIT(a.studios, '|') AS s
    WHERE ISNUMERIC(score) = 1
)

SELECT
    Studio,
    Rating AS AverageRating
FROM StudioData
GROUP BY Studio, Rating
ORDER BY AverageRating DESC;

---------------------------------------------------------------------------------

--Looking at which genre attracts most user engagment based on plan to watch count
WITH Genre AS (
    SELECT
        s.value AS Genre,
        CAST(plan_to_watch_count AS INT) AS PlanToWatchCount
    FROM Anime..AnimeData a
    CROSS APPLY STRING_SPLIT(a.genres, '|') AS s
    WHERE ISNUMERIC(plan_to_watch_count) = 1
)

SELECT
    TOP 10 Genre,
    SUM(PlanToWatchCount) AS TotalPlanToWatchCount
FROM Genre
GROUP BY Genre
ORDER BY TotalPlanToWatchCount DESC;

---------------------------------------------------------------------------------

--Looking at the anime people are most excited to watch that has not aired yet
SELECT TOP 10 title, plan_to_watch_count
FROM Anime..AnimeData
WHERE status = 'Not Yet Aired'
ORDER BY plan_to_watch_count DESC;
