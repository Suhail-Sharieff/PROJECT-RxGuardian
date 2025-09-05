const init_query = `
-- ===============================
-- Pharmacist Table
-- ===============================
CREATE TABLE IF NOT EXISTS pharmacist (
    pharmacist_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    dob VARCHAR(20) NOT NULL,
    address VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    password VARCHAR(20) NOT NULL,
    email VARCHAR(50) UNIQUE NOT NULL
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
    password VARCHAR(50) NOT NULL
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
    established DATETIME DEFAULT NOW(),
    CONSTRAINT fk_manager FOREIGN KEY (manager_id) 
        REFERENCES pharmacist(pharmacist_id) ON DELETE SET NULL
);

-- ===============================
-- Drug Table
-- ===============================
CREATE TABLE IF NOT EXISTS drug (
    drug_id INT PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    barcode VARCHAR(50) NOT NULL UNIQUE,
    dose DOUBLE NOT NULL,
    code VARCHAR(50),
    cost_price DOUBLE NOT NULL,
    selling_price DOUBLE NOT NULL,
    manufacturer_id INT,
    production_date DATE NOT NULL DEFAULT (CURRENT_DATE()),
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
    date DATETIME DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sale_item (
    sale_item_id INT PRIMARY KEY AUTO_INCREMENT,
    sale_id INT,
    drug_id INT,
    quantity INT NOT NULL,
    discount DOUBLE NOT NULL,
    FOREIGN KEY (sale_id) REFERENCES sale(sale_id) ON DELETE CASCADE,
    FOREIGN KEY (drug_id) REFERENCES drug(drug_id) ON DELETE SET NULL
);

-- ===============================
-- Employee & Salary
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

-- Trigger: Insert into employee when pharmacist is added
DROP TRIGGER IF EXISTS trg_insert_employee_after_pharmacist;
CREATE TRIGGER trg_insert_employee_after_pharmacist
AFTER INSERT ON pharmacist
FOR EACH ROW
BEGIN
    INSERT INTO employee (pharmacist_id, shop_id)
    VALUES (NEW.pharmacist_id, NULL);
END;

-- Trigger: Insert salary when employee is added
DROP TRIGGER IF EXISTS trg_insert_salary_after_employee;
CREATE TRIGGER trg_insert_salary_after_employee
AFTER INSERT ON employee
FOR EACH ROW
BEGIN
    INSERT INTO salary (salary, emp_id)
    VALUES (0, NEW.emp_id);
END;



create table if not exists quantity(
drug_id int,
shop_id int,
quantity int not null default 0,
unique key(drug_id,shop_id),
foreign key (drug_id) references drug(drug_id) on delete
 cascade,
 foreign key(shop_id) references shop(shop_id) on delete CASCADE
);




`;




export {init_query}