-- ============================================================
-- Achievements Module — World DB Migration
-- Idempotent: safe to run on an existing installation.
--
-- This script handles incremental upgrades only.
-- For a fresh install, run sql/install/world/*.sql instead.
-- ============================================================

-- Ensure MyISAM -> InnoDB engine upgrade for DBC tables
-- (older installs used MyISAM; new installs default to InnoDB)
SET @db = DATABASE();

-- Helper procedure: convert a table to InnoDB if it is still MyISAM
DROP PROCEDURE IF EXISTS `ach_ensure_innodb`;
DELIMITER $$
CREATE PROCEDURE `ach_ensure_innodb`(IN tblname VARCHAR(64))
BEGIN
    DECLARE eng VARCHAR(32);
    SELECT ENGINE INTO eng
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tblname;
    IF eng = 'MyISAM' THEN
        SET @sql = CONCAT('ALTER TABLE `', tblname, '` ENGINE=InnoDB ROW_FORMAT=DYNAMIC');
        PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
    END IF;
END$$
DELIMITER ;

CALL ach_ensure_innodb('achievement_dbc');
CALL ach_ensure_innodb('achievement_criteria_dbc');
CALL ach_ensure_innodb('achievement_category_dbc');
CALL ach_ensure_innodb('achievement_criteria_data');
CALL ach_ensure_innodb('achievement_reward');
CALL ach_ensure_innodb('achievement_reward_locale');

DROP PROCEDURE IF EXISTS `ach_ensure_innodb`;

-- ============================================================
-- Ensure achievement_reward table exists (added post-initial release)
-- ============================================================
CREATE TABLE IF NOT EXISTS `achievement_reward` (
    `ID`           INT(11)          NOT NULL DEFAULT '0',
    `TitleA`       INT(11)          NOT NULL DEFAULT '0',
    `TitleH`       INT(11)          NOT NULL DEFAULT '0',
    `ItemID`       INT(11)          NOT NULL DEFAULT '0',
    `Sender`       INT(11)          NOT NULL DEFAULT '0',
    `Subject`      VARCHAR(255)     NOT NULL DEFAULT '',
    `Body`         TEXT             NOT NULL,
    `MailTemplateId` INT(11) UNSIGNED NOT NULL DEFAULT '0',
    PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Ensure achievement_reward_locale table exists
-- ============================================================
CREATE TABLE IF NOT EXISTS `achievement_reward_locale` (
    `ID`      INT(11)      NOT NULL DEFAULT '0',
    `locale`  VARCHAR(4)   NOT NULL DEFAULT '',
    `Subject` VARCHAR(255) NOT NULL DEFAULT '',
    `Body`    TEXT         NOT NULL,
    PRIMARY KEY (`ID`, `locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Ensure achievement_criteria_data table exists
-- ============================================================
CREATE TABLE IF NOT EXISTS `achievement_criteria_data` (
    `criteria_id` INT(10) UNSIGNED NOT NULL,
    `type`        TINYINT(3) UNSIGNED NOT NULL DEFAULT '0',
    `value1`      INT(10) UNSIGNED NOT NULL DEFAULT '0',
    `value2`      INT(10) UNSIGNED NOT NULL DEFAULT '0',
    `ScriptName`  VARCHAR(64)       NOT NULL DEFAULT '',
    PRIMARY KEY (`criteria_id`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Add missing indexes on DBC tables for faster criteria lookups
-- ============================================================

-- Index: achievement_criteria_dbc.Achievement_Id
SET @tbl = 'achievement_criteria_dbc';
SET @idx = 'idx_achievement_id';
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl AND INDEX_NAME = @idx) = 0,
    CONCAT('ALTER TABLE `', @tbl, '` ADD INDEX `', @idx, '` (`Achievement_Id`)'),
    'SELECT ''index already exists'' AS info'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Index: achievement_criteria_dbc.Type
SET @idx = 'idx_type';
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl AND INDEX_NAME = @idx) = 0,
    CONCAT('ALTER TABLE `', @tbl, '` ADD INDEX `', @idx, '` (`Type`)'),
    'SELECT ''index already exists'' AS info'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Index: achievement_dbc.Category
SET @tbl = 'achievement_dbc';
SET @idx = 'idx_category';
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl AND INDEX_NAME = @idx) = 0,
    CONCAT('ALTER TABLE `', @tbl, '` ADD INDEX `', @idx, '` (`Category`)'),
    'SELECT ''index already exists'' AS info'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Index: achievement_category_dbc.Parent
SET @tbl = 'achievement_category_dbc';
SET @idx = 'idx_parent';
SET @sql = IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl AND INDEX_NAME = @idx) = 0,
    CONCAT('ALTER TABLE `', @tbl, '` ADD INDEX `', @idx, '` (`Parent`)'),
    'SELECT ''index already exists'' AS info'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================
-- Remove invalid achievement_criteria_data entries for classes
-- and races that do not exist in Classic WoW.
-- Class 6 (Death Knight) only exists in WotLK.
-- Race 10 (Blood Elf) and Race 11 (Draenei) only exist in TBC+.
-- ============================================================
DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 6302  AND `type` = 2 AND `value1` = 6  AND `value2` = 2;
DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 6313  AND `type` = 2 AND `value1` = 6  AND `value2` = 1;
DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 6319  AND `type` = 2 AND `value1` = 8  AND `value2` = 10;
DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 6320  AND `type` = 2 AND `value1` = 2  AND `value2` = 11;
DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 9124  AND `type` = 2 AND `value1` = 0  AND `value2` = 10;
DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 9143  AND `type` = 2 AND `value1` = 0  AND `value2` = 11;
DELETE FROM `achievement_criteria_data` WHERE `criteria_id` = 11163 AND `type` = 2 AND `value1` = 4  AND `value2` = 10;
DELETE FROM `achievement_dbc` WHERE `ID` IN (3478, 3556, 3557, 3558, 3559, 3576, 3577, 3578, 3579, 3580, 3581, 3582, 3596, 3597, 3656);
