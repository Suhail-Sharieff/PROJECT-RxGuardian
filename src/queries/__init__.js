
const init_query=
`
CREATE TABLE pharmacist (
id int primary key auto_increment ,
name varchar(50) NOT NULL,
dob varchar(20) NOT NULL,
address varchar(100) NOT NULL,
phone varchar(20) NOT NULL,
password varchar(20) NOT NULL,
email varchar(50) unique not null
);
--------------------------------------------------------------------
create table manufacturer
(
manufacturer_id int primary key auto_increment,
name varchar(50) not null,
address varchar(50) not null,
phone varchar(50) not null,
email varchar(50) unique not null,
license varchar(50) not null,
password varchar(50) not null
);
-----------------------------------------------------------------------
CREATE TABLE shop (
    shop_id INT PRIMARY KEY AUTO_INCREMENT,
    address VARCHAR(50) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    manager_id INT, 
    license VARCHAR(50) NOT NULL,
    name VARCHAR(50) NOT NULL,
    established DATETIME DEFAULT NOW(),
    CONSTRAINT fk_manager FOREIGN KEY (manager_id) REFERENCES pharmacist(pharmacist_id) on delete set null
);
-----------------------------------------------------------------------

create table drug
(
drug_id int primary key,
type varchar(50)  not null,
barcode varchar(50) not null unique,
dose double not null,
code varchar(50),
cost_price double not null,
selling_price double not null,
manufacturer_id int,
production_date date not null default (current_date()),
expiry_date date not null,
name varchar(50) not null,
constraint fk_drug_manufacturer
foreign key (manufacturer_id)
references manufacturer(manufacturer_id)
on delete cascade
)
DELIMITER $$

CREATE TRIGGER trg_check_drug_validity
BEFORE INSERT ON drug
FOR EACH ROW
BEGIN
    -- Check expiry after production
    IF NEW.expiry_date <= NEW.production_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Expiry date must be after production date';
    END IF;

    -- Check selling price >= cost price
    IF NEW.selling_price < NEW.cost_price THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Selling price cannot be less than cost price';
    END IF;
END$$
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
END$$
DELIMITER ;

----------------------------------------------

create table sale (
    sale_id INT primary key auto_increment,
    date datetime default NOW()
);
create table sale_item(
sale_item_id int primary key auto_increment,
sale_id int,
drug_id int,
quantity int not null,
discount double not null,
foreign key(sale_id) references sale(sale_id) on delete cascade,
foreign key(drug_id) references drug(drug_id) on delete set null
);

-------------------------------------------------------

create table employee(
emp_id int primary key auto_increment,
pharmacist_id int,
shop_id int,
constraint fk_pharmacist_id foreign key(pharmacist_id) references pharmacist(pharmacist_id) on delete cascade,
constraint fk_working_shop_id foreign key(shop_id) references shop(shop_id) on delete set null
);

create table salary(
salary_id int primary key auto_increment,
salary double not null default 0,
emp_id int not null,
constraint foreign key(emp_id) references employee(emp_id) on delete cascade
)












`