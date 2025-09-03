

const createPhramacist = `
CREATE TABLE pharmacist (
id int primary key auto_increment ,
name varchar(50) NOT NULL,
dob varchar(20) NOT NULL,
address varchar(100) NOT NULL,
phone varchar(20) NOT NULL,
password varchar(20) NOT NULL,
email varchar(50) unique not null
)`

const createManufacturer=
`create table manufacturer
(
manufacturer_id int primary key auto_increment,
name varchar(50) not null,
address varchar(50) not null,
phone varchar(50) not null,
email varchar(50) unique not null,
license varchar(50) not null,
password varchar(50) not null
)`

const createShop=`CREATE TABLE shop (
    shop_id INT PRIMARY KEY AUTO_INCREMENT,
    address VARCHAR(50) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    manager_id INT, 
    license VARCHAR(50) NOT NULL,
    name VARCHAR(50) NOT NULL,
    established DATETIME DEFAULT NOW(),
    CONSTRAINT fk_manager FOREIGN KEY (manager_id) REFERENCES pharmacist(pharmacist_id) on delete set null
);
`