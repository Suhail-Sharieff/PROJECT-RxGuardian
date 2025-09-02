

const createPhramacist = `
CREATE TABLE pharmacist (
id int primary key auto_increment ,
name varchar(50) NOT NULL,
dob varchar(20) NOT NULL,
address varchar(100) NOT NULL,
phone varchar(20) NOT NULL,
password varchar(20) NOT NULL,
email varchar(50) unique not null
) ) `