-- MySQL 8.0+
-- Creates an isolated database for the assignment.

DROP DATABASE IF EXISTS collections_analytics;
CREATE DATABASE collections_analytics
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE collections_analytics;

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET SESSION time_zone = '+05:30';
