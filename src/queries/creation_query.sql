-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema mydb
-- -----------------------------------------------------
-- -----------------------------------------------------
-- Schema rxguardian
-- -----------------------------------------------------

-- -----------------------------------------------------
-- Schema rxguardian
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `rxguardian` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci ;
USE `rxguardian` ;

-- -----------------------------------------------------
-- Table `rxguardian`.`pharmacist`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`pharmacist` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`pharmacist` (
  `pharmacist_id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  `dob` DATE NULL DEFAULT NULL,
  `address` VARCHAR(100) NOT NULL,
  `phone` VARCHAR(20) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  `email` VARCHAR(100) NULL DEFAULT NULL,
  `refreshToken` TEXT NULL DEFAULT NULL,
  `joined_date` DATE NOT NULL DEFAULT curdate(),
  PRIMARY KEY (`pharmacist_id`),
  UNIQUE INDEX `unique_email` (`email` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 24
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`shop`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`shop` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`shop` (
  `shop_id` INT NOT NULL AUTO_INCREMENT,
  `address` VARCHAR(50) NOT NULL,
  `phone` VARCHAR(50) NOT NULL,
  `manager_id` INT NULL DEFAULT NULL,
  `license` VARCHAR(50) NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `established` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`shop_id`),
  INDEX `fk_manager` (`manager_id` ASC) VISIBLE,
  CONSTRAINT `fk_manager`
    FOREIGN KEY (`manager_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE SET NULL)
ENGINE = InnoDB
AUTO_INCREMENT = 14
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`balance`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`balance` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`balance` (
  `shop_id` INT NOT NULL,
  `balance` DOUBLE NOT NULL DEFAULT '0',
  INDEX `shop_id` (`shop_id` ASC) VISIBLE,
  CONSTRAINT `balance_ibfk_1`
    FOREIGN KEY (`shop_id`)
    REFERENCES `rxguardian`.`shop` (`shop_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`chat_rooms`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`chat_rooms` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`chat_rooms` (
  `room_id` INT NOT NULL AUTO_INCREMENT,
  `room_name` VARCHAR(100) NOT NULL,
  `room_type` ENUM('general', 'shop', 'private') NULL DEFAULT 'general',
  `shop_id` INT NULL DEFAULT NULL,
  `created_by` INT NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_active` TINYINT(1) NULL DEFAULT '1',
  PRIMARY KEY (`room_id`),
  INDEX `shop_id` (`shop_id` ASC) VISIBLE,
  INDEX `created_by` (`created_by` ASC) VISIBLE,
  CONSTRAINT `chat_rooms_ibfk_1`
    FOREIGN KEY (`shop_id`)
    REFERENCES `rxguardian`.`shop` (`shop_id`)
    ON DELETE CASCADE,
  CONSTRAINT `chat_rooms_ibfk_2`
    FOREIGN KEY (`created_by`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 4
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`chat_messages`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`chat_messages` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`chat_messages` (
  `message_id` INT NOT NULL AUTO_INCREMENT,
  `room_id` INT NOT NULL,
  `sender_id` INT NOT NULL,
  `message_text` TEXT NOT NULL,
  `message_type` ENUM('text', 'image', 'file', 'system') NULL DEFAULT 'text',
  `file_url` VARCHAR(500) NULL DEFAULT NULL,
  `file_name` VARCHAR(255) NULL DEFAULT NULL,
  `file_size` INT NULL DEFAULT NULL,
  `reply_to_message_id` INT NULL DEFAULT NULL,
  `is_edited` TINYINT(1) NULL DEFAULT '0',
  `edited_at` TIMESTAMP NULL DEFAULT NULL,
  `is_deleted` TINYINT(1) NULL DEFAULT '0',
  `deleted_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`message_id`),
  INDEX `reply_to_message_id` (`reply_to_message_id` ASC) VISIBLE,
  INDEX `idx_chat_messages_room_created` (`room_id` ASC, `created_at` ASC) VISIBLE,
  INDEX `idx_chat_messages_sender` (`sender_id` ASC) VISIBLE,
  CONSTRAINT `chat_messages_ibfk_1`
    FOREIGN KEY (`room_id`)
    REFERENCES `rxguardian`.`chat_rooms` (`room_id`)
    ON DELETE CASCADE,
  CONSTRAINT `chat_messages_ibfk_2`
    FOREIGN KEY (`sender_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE CASCADE,
  CONSTRAINT `chat_messages_ibfk_3`
    FOREIGN KEY (`reply_to_message_id`)
    REFERENCES `rxguardian`.`chat_messages` (`message_id`)
    ON DELETE SET NULL)
ENGINE = InnoDB
AUTO_INCREMENT = 43
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`chat_room_members`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`chat_room_members` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`chat_room_members` (
  `member_id` INT NOT NULL AUTO_INCREMENT,
  `room_id` INT NOT NULL,
  `pharmacist_id` INT NOT NULL,
  `joined_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `last_read_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `is_admin` TINYINT(1) NULL DEFAULT '0',
  `is_muted` TINYINT(1) NULL DEFAULT '0',
  `is_active` TINYINT(1) NULL DEFAULT '1',
  `last_read_timestamp` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`member_id`),
  UNIQUE INDEX `unique_room_member` (`room_id` ASC, `pharmacist_id` ASC) VISIBLE,
  INDEX `pharmacist_id` (`pharmacist_id` ASC) VISIBLE,
  CONSTRAINT `chat_room_members_ibfk_1`
    FOREIGN KEY (`room_id`)
    REFERENCES `rxguardian`.`chat_rooms` (`room_id`)
    ON DELETE CASCADE,
  CONSTRAINT `chat_room_members_ibfk_2`
    FOREIGN KEY (`pharmacist_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 17
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`customer`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`customer` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`customer` (
  `customer_id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  `phone` VARCHAR(11) NOT NULL,
  PRIMARY KEY (`customer_id`),
  UNIQUE INDEX `phone` (`phone` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 27
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`manufacturer`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`manufacturer` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`manufacturer` (
  `manufacturer_id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL,
  `address` VARCHAR(50) NOT NULL,
  `phone` VARCHAR(50) NOT NULL,
  `email` VARCHAR(50) NOT NULL,
  `license` VARCHAR(50) NOT NULL,
  `password` VARCHAR(200) NULL DEFAULT NULL,
  PRIMARY KEY (`manufacturer_id`),
  UNIQUE INDEX `email` (`email` ASC) VISIBLE)
ENGINE = InnoDB
AUTO_INCREMENT = 58
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`drug`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`drug` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`drug` (
  `drug_id` INT NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(50) NOT NULL,
  `barcode` VARCHAR(50) NOT NULL,
  `dose` DOUBLE NOT NULL,
  `code` VARCHAR(50) NULL DEFAULT NULL,
  `cost_price` DOUBLE NOT NULL,
  `selling_price` DOUBLE NOT NULL,
  `manufacturer_id` INT NULL DEFAULT NULL,
  `production_date` DATE NOT NULL DEFAULT curdate(),
  `expiry_date` DATE NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  PRIMARY KEY (`drug_id`),
  UNIQUE INDEX `barcode` (`barcode` ASC) VISIBLE,
  INDEX `fk_drug_manufacturer` (`manufacturer_id` ASC) VISIBLE,
  CONSTRAINT `fk_drug_manufacturer`
    FOREIGN KEY (`manufacturer_id`)
    REFERENCES `rxguardian`.`manufacturer` (`manufacturer_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 91
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`employee`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`employee` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`employee` (
  `emp_id` INT NOT NULL AUTO_INCREMENT,
  `pharmacist_id` INT NULL DEFAULT NULL,
  `shop_id` INT NULL DEFAULT NULL,
  PRIMARY KEY (`emp_id`),
  INDEX `fk_pharmacist_id` (`pharmacist_id` ASC) VISIBLE,
  INDEX `fk_working_shop_id` (`shop_id` ASC) VISIBLE,
  CONSTRAINT `fk_pharmacist_id`
    FOREIGN KEY (`pharmacist_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_working_shop_id`
    FOREIGN KEY (`shop_id`)
    REFERENCES `rxguardian`.`shop` (`shop_id`)
    ON DELETE SET NULL)
ENGINE = InnoDB
AUTO_INCREMENT = 23
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`message_reactions`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`message_reactions` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`message_reactions` (
  `reaction_id` INT NOT NULL AUTO_INCREMENT,
  `message_id` INT NOT NULL,
  `pharmacist_id` INT NOT NULL,
  `emoji` VARCHAR(10) NOT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`reaction_id`),
  UNIQUE INDEX `unique_reaction` (`message_id` ASC, `pharmacist_id` ASC) VISIBLE,
  INDEX `pharmacist_id` (`pharmacist_id` ASC) VISIBLE,
  CONSTRAINT `message_reactions_ibfk_1`
    FOREIGN KEY (`message_id`)
    REFERENCES `rxguardian`.`chat_messages` (`message_id`)
    ON DELETE CASCADE,
  CONSTRAINT `message_reactions_ibfk_2`
    FOREIGN KEY (`pharmacist_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 3
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`message_read_status`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`message_read_status` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`message_read_status` (
  `read_id` INT NOT NULL AUTO_INCREMENT,
  `message_id` INT NOT NULL,
  `pharmacist_id` INT NOT NULL,
  `read_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`read_id`),
  UNIQUE INDEX `unique_read` (`message_id` ASC, `pharmacist_id` ASC) VISIBLE,
  INDEX `pharmacist_id` (`pharmacist_id` ASC) VISIBLE,
  INDEX `idx_message_read_status_message` (`message_id` ASC) VISIBLE,
  CONSTRAINT `message_read_status_ibfk_1`
    FOREIGN KEY (`message_id`)
    REFERENCES `rxguardian`.`chat_messages` (`message_id`)
    ON DELETE CASCADE,
  CONSTRAINT `message_read_status_ibfk_2`
    FOREIGN KEY (`pharmacist_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 2
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`online_users`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`online_users` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`online_users` (
  `pharmacist_id` INT NOT NULL,
  `socket_id` VARCHAR(100) NOT NULL,
  `last_seen` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `status` VARCHAR(20) NULL DEFAULT NULL,
  `current_room_id` INT NULL DEFAULT NULL,
  PRIMARY KEY (`pharmacist_id`),
  INDEX `current_room_id` (`current_room_id` ASC) VISIBLE,
  INDEX `idx_online_users_status` (`status` ASC) VISIBLE,
  CONSTRAINT `online_users_ibfk_1`
    FOREIGN KEY (`pharmacist_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE CASCADE,
  CONSTRAINT `online_users_ibfk_2`
    FOREIGN KEY (`current_room_id`)
    REFERENCES `rxguardian`.`chat_rooms` (`room_id`)
    ON DELETE SET NULL)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`quantity`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`quantity` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`quantity` (
  `drug_id` INT NULL DEFAULT NULL,
  `shop_id` INT NULL DEFAULT NULL,
  `quantity` INT NOT NULL DEFAULT '0',
  UNIQUE INDEX `drug_id` (`drug_id` ASC, `shop_id` ASC) VISIBLE,
  INDEX `shop_id` (`shop_id` ASC) VISIBLE,
  CONSTRAINT `quantity_ibfk_1`
    FOREIGN KEY (`drug_id`)
    REFERENCES `rxguardian`.`drug` (`drug_id`)
    ON DELETE CASCADE,
  CONSTRAINT `quantity_ibfk_2`
    FOREIGN KEY (`shop_id`)
    REFERENCES `rxguardian`.`shop` (`shop_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`salary`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`salary` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`salary` (
  `salary_id` INT NOT NULL AUTO_INCREMENT,
  `salary` DOUBLE NOT NULL DEFAULT '0',
  `emp_id` INT NOT NULL,
  PRIMARY KEY (`salary_id`),
  INDEX `emp_id` (`emp_id` ASC) VISIBLE,
  CONSTRAINT `salary_ibfk_1`
    FOREIGN KEY (`emp_id`)
    REFERENCES `rxguardian`.`employee` (`emp_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 23
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`sale`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`sale` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`sale` (
  `sale_id` INT NOT NULL AUTO_INCREMENT,
  `date` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `shop_id` INT NOT NULL,
  `pharmacist_id` INT NULL DEFAULT NULL,
  `discount` INT NULL DEFAULT '0',
  `customer_id` INT NULL DEFAULT NULL,
  PRIMARY KEY (`sale_id`),
  INDEX `fk_shop_id` (`shop_id` ASC) VISIBLE,
  INDEX `fk_sale_pharmacist` (`pharmacist_id` ASC) VISIBLE,
  INDEX `fk_sale_customer` (`customer_id` ASC) VISIBLE,
  CONSTRAINT `fk_sale_customer`
    FOREIGN KEY (`customer_id`)
    REFERENCES `rxguardian`.`customer` (`customer_id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_sale_pharmacist`
    FOREIGN KEY (`pharmacist_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT `fk_shop_id`
    FOREIGN KEY (`shop_id`)
    REFERENCES `rxguardian`.`shop` (`shop_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 52
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`sale_item`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`sale_item` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`sale_item` (
  `sale_item_id` INT NOT NULL AUTO_INCREMENT,
  `sale_id` INT NULL DEFAULT NULL,
  `drug_id` INT NULL DEFAULT NULL,
  `quantity` INT NOT NULL,
  PRIMARY KEY (`sale_item_id`),
  INDEX `sale_id` (`sale_id` ASC) VISIBLE,
  INDEX `drug_id` (`drug_id` ASC) VISIBLE,
  CONSTRAINT `sale_item_ibfk_1`
    FOREIGN KEY (`sale_id`)
    REFERENCES `rxguardian`.`sale` (`sale_id`)
    ON DELETE CASCADE,
  CONSTRAINT `sale_item_ibfk_2`
    FOREIGN KEY (`drug_id`)
    REFERENCES `rxguardian`.`drug` (`drug_id`)
    ON DELETE SET NULL)
ENGINE = InnoDB
AUTO_INCREMENT = 73
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;


-- -----------------------------------------------------
-- Table `rxguardian`.`typing_indicators`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `rxguardian`.`typing_indicators` ;

CREATE TABLE IF NOT EXISTS `rxguardian`.`typing_indicators` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `room_id` INT NOT NULL,
  `pharmacist_id` INT NOT NULL,
  `is_typing` TINYINT(1) NULL DEFAULT '1',
  `started_typing_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `unique_typing` (`room_id` ASC, `pharmacist_id` ASC) VISIBLE,
  INDEX `pharmacist_id` (`pharmacist_id` ASC) VISIBLE,
  INDEX `idx_typing_indicators_room` (`room_id` ASC) VISIBLE,
  CONSTRAINT `typing_indicators_ibfk_1`
    FOREIGN KEY (`room_id`)
    REFERENCES `rxguardian`.`chat_rooms` (`room_id`)
    ON DELETE CASCADE,
  CONSTRAINT `typing_indicators_ibfk_2`
    FOREIGN KEY (`pharmacist_id`)
    REFERENCES `rxguardian`.`pharmacist` (`pharmacist_id`)
    ON DELETE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 27
DEFAULT CHARACTER SET = utf8mb4
COLLATE = utf8mb4_0900_ai_ci;

USE `rxguardian`;

DELIMITER $$

USE `rxguardian`$$
DROP TRIGGER IF EXISTS `rxguardian`.`trg_insert_employee_after_pharmacist` $$
USE `rxguardian`$$
CREATE
DEFINER=`RxGuardian`@`localhost`
TRIGGER `rxguardian`.`trg_insert_employee_after_pharmacist`
AFTER INSERT ON `rxguardian`.`pharmacist`
FOR EACH ROW
BEGIN
    INSERT INTO employee (pharmacist_id, shop_id)
    VALUES (NEW.pharmacist_id, NULL);
END$$


USE `rxguardian`$$
DROP TRIGGER IF EXISTS `rxguardian`.`after_shop_insert` $$
USE `rxguardian`$$
CREATE
DEFINER=`RxGuardian`@`localhost`
TRIGGER `rxguardian`.`after_shop_insert`
AFTER INSERT ON `rxguardian`.`shop`
FOR EACH ROW
BEGIN
    IF NEW.manager_id IS NOT NULL THEN
        UPDATE employee
        SET shop_id = NEW.shop_id
        WHERE pharmacist_id = NEW.manager_id;
    END IF;
END$$


USE `rxguardian`$$
DROP TRIGGER IF EXISTS `rxguardian`.`after_shop_update` $$
USE `rxguardian`$$
CREATE
DEFINER=`RxGuardian`@`localhost`
TRIGGER `rxguardian`.`after_shop_update`
AFTER UPDATE ON `rxguardian`.`shop`
FOR EACH ROW
BEGIN
    -- Case 1: Manager removed
    IF NEW.manager_id IS NULL AND OLD.manager_id IS NOT NULL THEN
        UPDATE employee
        SET shop_id = NULL
        WHERE pharmacist_id = OLD.manager_id
          AND shop_id = OLD.shop_id;
    END IF;

    -- Case 2: Manager changed
    IF NEW.manager_id IS NOT NULL AND NEW.manager_id <> OLD.manager_id THEN
        -- Remove old manager link
        UPDATE employee
        SET shop_id = NULL
        WHERE pharmacist_id = OLD.manager_id
          AND shop_id = OLD.shop_id;

        -- Assign new manager to this shop
        UPDATE employee
        SET shop_id = NEW.shop_id
        WHERE pharmacist_id = NEW.manager_id;
    END IF;
END$$


USE `rxguardian`$$
DROP TRIGGER IF EXISTS `rxguardian`.`trg_after_shop_insert_into_balance` $$
USE `rxguardian`$$
CREATE
DEFINER=`RxGuardian`@`localhost`
TRIGGER `rxguardian`.`trg_after_shop_insert_into_balance`
AFTER INSERT ON `rxguardian`.`shop`
FOR EACH ROW
begin
   insert into balance(shop_id) values (new.shop_id);
end$$


USE `rxguardian`$$
DROP TRIGGER IF EXISTS `rxguardian`.`trg_check_drug_update` $$
USE `rxguardian`$$
CREATE
DEFINER=`RxGuardian`@`localhost`
TRIGGER `rxguardian`.`trg_check_drug_update`
BEFORE UPDATE ON `rxguardian`.`drug`
FOR EACH ROW
BEGIN
    IF NEW.expiry_date <= NEW.production_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Expiry date must be after production date';
    END IF;

    IF NEW.selling_price < NEW.cost_price THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Selling price cannot be less than cost price';
    END IF;
END$$


USE `rxguardian`$$
DROP TRIGGER IF EXISTS `rxguardian`.`trg_check_drug_validity` $$
USE `rxguardian`$$
CREATE
DEFINER=`RxGuardian`@`localhost`
TRIGGER `rxguardian`.`trg_check_drug_validity`
BEFORE INSERT ON `rxguardian`.`drug`
FOR EACH ROW
BEGIN
    IF NEW.expiry_date <= NEW.production_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Expiry date must be after production date';
    END IF;

    IF NEW.selling_price < NEW.cost_price THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Selling price cannot be less than cost price';
    END IF;
END$$


USE `rxguardian`$$
DROP TRIGGER IF EXISTS `rxguardian`.`trg_insert_salary_after_employee` $$
USE `rxguardian`$$
CREATE
DEFINER=`RxGuardian`@`localhost`
TRIGGER `rxguardian`.`trg_insert_salary_after_employee`
AFTER INSERT ON `rxguardian`.`employee`
FOR EACH ROW
BEGIN
    INSERT INTO salary (salary, emp_id)
    VALUES (0, NEW.emp_id);
END$$


DELIMITER ;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
