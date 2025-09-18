const init_query = `
-- ===============================
-- Schema
-- ===============================
CREATE SCHEMA IF NOT EXISTS rxguardian DEFAULT CHARACTER SET utf8mb4;
USE rxguardian;

-- ===============================
-- Customer Table
-- ===============================
CREATE TABLE IF NOT EXISTS customer (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(11) NOT NULL UNIQUE
);

-- ===============================
-- Manufacturer Table
-- ===============================
CREATE TABLE IF NOT EXISTS manufacturer (
    manufacturer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    address VARCHAR(50) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(50) UNIQUE NOT NULL,
    license VARCHAR(50) NOT NULL,
    password VARCHAR(200)
);

-- ===============================
-- Pharmacist Table
-- ===============================
CREATE TABLE IF NOT EXISTS pharmacist (
    pharmacist_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    dob DATE,
    address VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    refreshToken TEXT,
    joined_date DATE NOT NULL DEFAULT (CURRENT_DATE)
);

-- ===============================
-- Shop Table
-- ===============================
CREATE TABLE IF NOT EXISTS shop (
    shop_id INT PRIMARY KEY AUTO_INCREMENT,
    address VARCHAR(50) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    manager_id INT,
    license VARCHAR(50) NOT NULL,
    name VARCHAR(50) NOT NULL,
    established DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_manager FOREIGN KEY (manager_id)
        REFERENCES pharmacist(pharmacist_id) ON DELETE SET NULL
);

-- ===============================
-- Employee & Salary Tables
-- ===============================
CREATE TABLE IF NOT EXISTS employee (
    emp_id INT PRIMARY KEY AUTO_INCREMENT,
    pharmacist_id INT,
    shop_id INT,
    CONSTRAINT fk_pharmacist_id FOREIGN KEY (pharmacist_id)
        REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE,
    CONSTRAINT fk_working_shop_id FOREIGN KEY (shop_id)
        REFERENCES shop(shop_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS salary (
    salary_id INT PRIMARY KEY AUTO_INCREMENT,
    salary DOUBLE NOT NULL DEFAULT 0,
    emp_id INT NOT NULL,
    FOREIGN KEY (emp_id) REFERENCES employee(emp_id) ON DELETE CASCADE
);

-- ===============================
-- Drug Table
-- ===============================
CREATE TABLE IF NOT EXISTS drug (
    drug_id INT PRIMARY KEY AUTO_INCREMENT,
    type VARCHAR(50) NOT NULL,
    barcode VARCHAR(50) NOT NULL UNIQUE,
    dose DOUBLE NOT NULL,
    code VARCHAR(50),
    cost_price DOUBLE NOT NULL,
    selling_price DOUBLE NOT NULL,
    manufacturer_id INT,
    production_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    name VARCHAR(50) NOT NULL,
    CONSTRAINT fk_drug_manufacturer FOREIGN KEY (manufacturer_id)
        REFERENCES manufacturer(manufacturer_id) ON DELETE CASCADE
);

-- ===============================
-- Sale & Sale Items
-- ===============================
CREATE TABLE IF NOT EXISTS sale (
    sale_id INT PRIMARY KEY AUTO_INCREMENT,
    date DATETIME DEFAULT CURRENT_TIMESTAMP,
    shop_id INT NOT NULL,
    pharmacist_id INT,
    discount INT DEFAULT 0,
    customer_id INT,
    FOREIGN KEY (shop_id) REFERENCES shop(shop_id) ON DELETE CASCADE,
    FOREIGN KEY (pharmacist_id) REFERENCES pharmacist(pharmacist_id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS sale_item (
    sale_item_id INT PRIMARY KEY AUTO_INCREMENT,
    sale_id INT,
    drug_id INT,
    quantity INT NOT NULL,
    FOREIGN KEY (sale_id) REFERENCES sale(sale_id) ON DELETE CASCADE,
    FOREIGN KEY (drug_id) REFERENCES drug(drug_id) ON DELETE SET NULL
);

-- ===============================
-- Quantity Table
-- ===============================
CREATE TABLE IF NOT EXISTS quantity (
    drug_id INT,
    shop_id INT,
    quantity INT NOT NULL DEFAULT 0,
    UNIQUE KEY(drug_id, shop_id),
    FOREIGN KEY (drug_id) REFERENCES drug(drug_id) ON DELETE CASCADE,
    FOREIGN KEY (shop_id) REFERENCES shop(shop_id) ON DELETE CASCADE
);

-- ===============================
-- Balance Table
-- ===============================
create table if not exists balance (
shop_id int not null,
balance double not null default 0,
foreign key(shop_id) references shop(shop_id) on delete cascade
);




-- ===============================
-- Triggers
-- ===============================

-- Trigger: Check drug validity before insert
DROP TRIGGER IF EXISTS trg_check_drug_validity;
CREATE TRIGGER trg_check_drug_validity
BEFORE INSERT ON drug
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
END;

-- Trigger: Check drug validity before update
DROP TRIGGER IF EXISTS trg_check_drug_update;
CREATE TRIGGER trg_check_drug_update
BEFORE UPDATE ON drug
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
END;

-- Trigger: Insert employee after pharmacist creation
DROP TRIGGER IF EXISTS trg_insert_employee_after_pharmacist;
CREATE TRIGGER trg_insert_employee_after_pharmacist
AFTER INSERT ON pharmacist
FOR EACH ROW
BEGIN
    INSERT INTO employee (pharmacist_id, shop_id)
    VALUES (NEW.pharmacist_id, NULL);
END;

-- Trigger: Insert salary after employee creation
DROP TRIGGER IF EXISTS trg_insert_salary_after_employee;
CREATE TRIGGER trg_insert_salary_after_employee
AFTER INSERT ON employee
FOR EACH ROW
BEGIN
    INSERT INTO salary (salary, emp_id)
    VALUES (0, NEW.emp_id);
END;



-- Whenever a shop is created, set its balance to 0
DROP TRIGGER IF EXISTS trg_after_shop_insert_into_balance;
create trigger trg_after_shop_insert_into_balance
after insert on shop
for each row
begin
   insert into balance(shop_id) values (new.shop_id);
end;

-- ===============================
-- Chat System Tables
-- ===============================

-- Chat Rooms Table
CREATE TABLE IF NOT EXISTS chat_rooms (
    room_id INT PRIMARY KEY AUTO_INCREMENT,
    room_name VARCHAR(100) NOT NULL,
    room_type ENUM('general', 'shop', 'private') DEFAULT 'general',
    shop_id INT NULL,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (shop_id) REFERENCES shop(shop_id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE
);

-- Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
    message_id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    sender_id INT NOT NULL,
    message_text TEXT NOT NULL,
    message_type ENUM('text', 'image', 'file', 'system') DEFAULT 'text',
    file_url VARCHAR(500) NULL,
    file_name VARCHAR(255) NULL,
    file_size INT NULL,
    reply_to_message_id INT NULL,
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES chat_rooms(room_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE,
    FOREIGN KEY (reply_to_message_id) REFERENCES chat_messages(message_id) ON DELETE SET NULL
);

-- Chat Room Members Table
CREATE TABLE IF NOT EXISTS chat_room_members (
    member_id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    pharmacist_id INT NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_admin BOOLEAN DEFAULT FALSE,
    is_muted BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE KEY unique_room_member (room_id, pharmacist_id),
    FOREIGN KEY (room_id) REFERENCES chat_rooms(room_id) ON DELETE CASCADE,
    FOREIGN KEY (pharmacist_id) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE
);

-- Online Users Table (for tracking who's online)
CREATE TABLE IF NOT EXISTS online_users (
    pharmacist_id INT PRIMARY KEY,
    socket_id VARCHAR(100) NOT NULL,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('online', 'away', 'busy', 'invisible') DEFAULT 'online',
    current_room_id INT NULL,
    FOREIGN KEY (pharmacist_id) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE,
    FOREIGN KEY (current_room_id) REFERENCES chat_rooms(room_id) ON DELETE SET NULL
);

-- Typing Indicators Table
CREATE TABLE IF NOT EXISTS typing_indicators (
    id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    pharmacist_id INT NOT NULL,
    is_typing BOOLEAN DEFAULT TRUE,
    started_typing_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES chat_rooms(room_id) ON DELETE CASCADE,
    FOREIGN KEY (pharmacist_id) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE,
    UNIQUE KEY unique_typing (room_id, pharmacist_id)
);

-- Message Reactions Table
CREATE TABLE IF NOT EXISTS message_reactions (
    reaction_id INT PRIMARY KEY AUTO_INCREMENT,
    message_id INT NOT NULL,
    pharmacist_id INT NOT NULL,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_reaction (message_id, pharmacist_id),
    FOREIGN KEY (message_id) REFERENCES chat_messages(message_id) ON DELETE CASCADE,
    FOREIGN KEY (pharmacist_id) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE
);

-- Message Read Status Table
CREATE TABLE IF NOT EXISTS message_read_status (
    read_id INT PRIMARY KEY AUTO_INCREMENT,
    message_id INT NOT NULL,
    pharmacist_id INT NOT NULL,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_read (message_id, pharmacist_id),
    FOREIGN KEY (message_id) REFERENCES chat_messages(message_id) ON DELETE CASCADE,
    FOREIGN KEY (pharmacist_id) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE
);

-- Create indexes for better performance


-- Create default general chat room (only if no rooms exist)
INSERT IGNORE INTO chat_rooms (room_id, room_name, room_type, created_by) 
SELECT 1, 'General Chat', 'general', 1
WHERE NOT EXISTS (SELECT 1 FROM chat_rooms WHERE room_id = 1);

`;

export { init_query };
