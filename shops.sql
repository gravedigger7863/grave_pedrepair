CREATE TABLE IF NOT EXISTS `repair_shops` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `repairSpotX` float NOT NULL,
  `repairSpotY` float NOT NULL,
  `repairSpotZ` float NOT NULL,
  `pedSpawnX` float NOT NULL,
  `pedSpawnY` float NOT NULL,
  `pedSpawnZ` float NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
