-- MySQL dump 10.13  Distrib 8.0.43, for Win64 (x86_64)
--
-- Host: 127.0.0.1    Database: rxguardian
-- ------------------------------------------------------
-- Server version	8.0.43

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `balance`
--

DROP TABLE IF EXISTS `balance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `balance` (
  `shop_id` int NOT NULL,
  `balance` double NOT NULL DEFAULT '0',
  KEY `shop_id` (`shop_id`),
  CONSTRAINT `balance_ibfk_1` FOREIGN KEY (`shop_id`) REFERENCES `shop` (`shop_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `balance`
--

LOCK TABLES `balance` WRITE;
/*!40000 ALTER TABLE `balance` DISABLE KEYS */;
INSERT INTO `balance` VALUES (12,0),(12,4580.75),(5,923.4),(2,18765.2),(6,6421),(4,2350.9),(7,12005.6),(1,317.26000000000005),(13,0),(14,0);
/*!40000 ALTER TABLE `balance` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `chat_messages`
--

DROP TABLE IF EXISTS `chat_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_messages` (
  `message_id` int NOT NULL AUTO_INCREMENT,
  `room_id` int NOT NULL,
  `sender_id` int NOT NULL,
  `message_text` text NOT NULL,
  `message_type` enum('text','image','file','system') DEFAULT 'text',
  `file_url` varchar(500) DEFAULT NULL,
  `file_name` varchar(255) DEFAULT NULL,
  `file_size` int DEFAULT NULL,
  `reply_to_message_id` int DEFAULT NULL,
  `is_edited` tinyint(1) DEFAULT '0',
  `edited_at` timestamp NULL DEFAULT NULL,
  `is_deleted` tinyint(1) DEFAULT '0',
  `deleted_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`message_id`),
  KEY `reply_to_message_id` (`reply_to_message_id`),
  KEY `idx_chat_messages_room_created` (`room_id`,`created_at`),
  KEY `idx_chat_messages_sender` (`sender_id`),
  CONSTRAINT `chat_messages_ibfk_1` FOREIGN KEY (`room_id`) REFERENCES `chat_rooms` (`room_id`) ON DELETE CASCADE,
  CONSTRAINT `chat_messages_ibfk_2` FOREIGN KEY (`sender_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE CASCADE,
  CONSTRAINT `chat_messages_ibfk_3` FOREIGN KEY (`reply_to_message_id`) REFERENCES `chat_messages` (`message_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=43 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `chat_messages`
--

LOCK TABLES `chat_messages` WRITE;
/*!40000 ALTER TABLE `chat_messages` DISABLE KEYS */;
/*!40000 ALTER TABLE `chat_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `chat_room_members`
--

DROP TABLE IF EXISTS `chat_room_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_room_members` (
  `member_id` int NOT NULL AUTO_INCREMENT,
  `room_id` int NOT NULL,
  `pharmacist_id` int NOT NULL,
  `joined_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `last_read_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `is_admin` tinyint(1) DEFAULT '0',
  `is_muted` tinyint(1) DEFAULT '0',
  `is_active` tinyint(1) DEFAULT '1',
  `last_read_timestamp` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`member_id`),
  UNIQUE KEY `unique_room_member` (`room_id`,`pharmacist_id`),
  KEY `pharmacist_id` (`pharmacist_id`),
  CONSTRAINT `chat_room_members_ibfk_1` FOREIGN KEY (`room_id`) REFERENCES `chat_rooms` (`room_id`) ON DELETE CASCADE,
  CONSTRAINT `chat_room_members_ibfk_2` FOREIGN KEY (`pharmacist_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `chat_room_members`
--

LOCK TABLES `chat_room_members` WRITE;
/*!40000 ALTER TABLE `chat_room_members` DISABLE KEYS */;
INSERT INTO `chat_room_members` VALUES (12,3,17,'2025-09-18 07:01:52','2025-09-18 07:51:27',1,0,1,'2025-09-19 16:29:28'),(16,3,23,'2025-09-18 10:56:21','2025-09-18 10:56:21',0,0,1,'2025-09-19 04:11:47');
/*!40000 ALTER TABLE `chat_room_members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `chat_rooms`
--

DROP TABLE IF EXISTS `chat_rooms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `chat_rooms` (
  `room_id` int NOT NULL AUTO_INCREMENT,
  `room_name` varchar(100) NOT NULL,
  `room_type` enum('general','shop','private') DEFAULT 'general',
  `shop_id` int DEFAULT NULL,
  `created_by` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`room_id`),
  KEY `shop_id` (`shop_id`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `chat_rooms_ibfk_1` FOREIGN KEY (`shop_id`) REFERENCES `shop` (`shop_id`) ON DELETE CASCADE,
  CONSTRAINT `chat_rooms_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `chat_rooms`
--

LOCK TABLES `chat_rooms` WRITE;
/*!40000 ALTER TABLE `chat_rooms` DISABLE KEYS */;
INSERT INTO `chat_rooms` VALUES (3,'New Room','shop',1,17,'2025-09-18 06:43:42','2025-09-18 06:43:42',1);
/*!40000 ALTER TABLE `chat_rooms` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `customer`
--

DROP TABLE IF EXISTS `customer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `customer` (
  `customer_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `phone` varchar(11) NOT NULL,
  PRIMARY KEY (`customer_id`),
  UNIQUE KEY `phone` (`phone`)
) ENGINE=InnoDB AUTO_INCREMENT=27 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `customer`
--

LOCK TABLES `customer` WRITE;
/*!40000 ALTER TABLE `customer` DISABLE KEYS */;
INSERT INTO `customer` VALUES (1,'Ramesh Kumar','9876543210'),(2,'Sita Verma','9123456780'),(3,'Amit Sharma','9988776655'),(4,'Priya Nair','9090909090'),(5,'Rajesh Patel','8765432109'),(6,'Anjali Gupta','9345678123'),(7,'Vikram Singh','9456123789'),(8,'Neha Reddy','9845123456'),(9,'Sanjay Mehta','9723456789'),(10,'Pooja Iyer','9612345678'),(11,'Arjun Malhotra','9512349876'),(12,'Meera Das','9654321870'),(13,'Kiran Joshi','9876012345'),(14,'Divya Kapoor','9823456712'),(15,'Rohit Bansal','9798123456'),(16,'Shreya Pillai','9734567890'),(17,'Naveen Rao','9687654321'),(18,'Tanvi Deshmukh','9623412345'),(19,'Harish Menon','9543218765'),(20,'Ayesha Khan','9478123456'),(21,'Mrinal','12343434343'),(22,'Kutteri','8618068225'),(23,'Katappa','1234567891'),(24,'Roshan','3456781234'),(25,'Madeeha','8618069881'),(26,'Veren','4567891234');
/*!40000 ALTER TABLE `customer` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `drug`
--

DROP TABLE IF EXISTS `drug`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `drug` (
  `drug_id` int NOT NULL AUTO_INCREMENT,
  `type` varchar(50) NOT NULL,
  `barcode` varchar(50) NOT NULL,
  `dose` double NOT NULL,
  `code` varchar(50) DEFAULT NULL,
  `cost_price` double NOT NULL,
  `selling_price` double NOT NULL,
  `manufacturer_id` int DEFAULT NULL,
  `production_date` date NOT NULL DEFAULT (curdate()),
  `expiry_date` date NOT NULL,
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`drug_id`),
  UNIQUE KEY `barcode` (`barcode`),
  KEY `fk_drug_manufacturer` (`manufacturer_id`),
  CONSTRAINT `fk_drug_manufacturer` FOREIGN KEY (`manufacturer_id`) REFERENCES `manufacturer` (`manufacturer_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=91 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `drug`
--

LOCK TABLES `drug` WRITE;
/*!40000 ALTER TABLE `drug` DISABLE KEYS */;
INSERT INTO `drug` VALUES (61,'Tablet','BARC0001',500,'AMOX500',2.5,5,27,'2025-01-15','2027-01-15','Amoxicillin 500mg'),(62,'Capsule','BARC0002',250,'VITC250',1.2,2.5,28,'2025-02-10','2026-08-10','Vitamin C 250mg'),(63,'Syrup','BARC0003',100,'COFSYR100',3,6.5,29,'2025-03-01','2026-03-01','Cough Syrup 100ml'),(64,'Injection','BARC0004',2,'INSUL2ML',50,80,30,'2025-01-20','2026-01-20','Insulin 2ml Injection'),(65,'Tablet','BARC0005',650,'PARA650',0.8,1.5,31,'2025-04-05','2028-04-05','Paracetamol 650mg'),(66,'Tablet','BARC0006',10,'IRON10',0.5,1,32,'2025-02-18','2027-02-18','Iron Supplement 10mg'),(67,'Capsule','BARC0007',400,'OME400',2,3.5,33,'2025-03-12','2026-09-12','Omeprazole 400mg'),(68,'Syrup','BARC0008',200,'ANTISYR200',4.5,8,34,'2025-01-30','2026-07-30','Antibiotic Syrup 200ml'),(69,'Tablet','BARC0009',20,'CAL20',0.6,1.2,35,'2025-04-15','2027-10-15','Calcium 20mg'),(70,'Tablet','BARC0010',100,'ASP100',1,1.8,36,'2025-02-22','2028-02-22','Aspirin 100mg'),(71,'Injection','BARC0011',5,'VACC5ML',100,150,37,'2025-01-25','2027-01-25','COVID Vaccine 5ml'),(72,'Tablet','BARC0012',50,'ANTI50',1.5,3,38,'2025-03-05','2026-09-05','Antihistamine 50mg'),(73,'Syrup','BARC0013',150,'MULTISYR150',5,9,39,'2025-02-28','2027-02-28','Multivitamin Syrup 150ml'),(74,'Capsule','BARC0014',500,'FISHOIL500',2.8,5.5,40,'2025-04-01','2026-10-01','Fish Oil 500mg'),(75,'Tablet','BARC0015',200,'CET200',0.7,1.4,41,'2025-03-18','2026-09-18','Cetirizine 200mg'),(76,'Injection','BARC0016',1,'B12SHOT',25,40,42,'2025-01-12','2026-07-12','Vitamin B12 Injection'),(77,'Tablet','BARC0017',75,'ANTIH75',1.2,2.2,43,'2025-02-08','2027-02-08','Antihypertensive 75mg'),(78,'Capsule','BARC0018',300,'PROBIO300',3,5.5,44,'2025-03-10','2026-09-10','Probiotic 300mg'),(79,'Tablet','BARC0019',150,'COLD150',0.9,1.8,45,'2025-04-20','2027-10-20','Cold Relief 150mg'),(80,'Syrup','BARC0020',250,'CHILDSYR250',4,7,46,'2025-02-25','2026-08-25','Children’s Syrup 250ml'),(81,'Tablet','BARC0021',1000,'CALCIUM1000',2.2,4.2,47,'2025-03-15','2028-03-15','Calcium 1000mg'),(82,'Injection','BARC0022',10,'PAINREL10',30,55,48,'2025-01-28','2026-07-28','Pain Relief Injection 10ml'),(83,'Capsule','BARC0023',250,'OMEGA250',2.1,3.9,49,'2025-02-14','2026-08-14','Omega-3 250mg'),(84,'Tablet','BARC0024',75,'ASPIRIN75',1,1.7,50,'2025-04-08','2028-04-08','Aspirin 75mg'),(85,'Tablet','BARC0025',20,'ZINC20',0.4,0.9,51,'2025-03-02','2026-09-02','Zinc 20mg'),(86,'Syrup','BARC0026',100,'COUGH100',2.8,5,52,'2025-02-19','2026-08-19','Cough Syrup 100ml'),(87,'Capsule','BARC0027',150,'VITA150',1.5,2.8,53,'2025-03-25','2027-09-25','Vitamin A 150mg'),(88,'Injection','BARC0028',2,'HEP2ML',60,100,54,'2025-01-17','2026-07-17','Hepatitis Vaccine 2ml'),(89,'Tablet','BARC0029',500,'IBU500',1.2,2.2,55,'2025-04-12','2027-10-12','Ibuprofen 500mg'),(90,'Tablet','BARC0030',400,'ANTACID400',0.9,1.6,56,'2025-02-05','2026-08-05','Antacid 400mg');
/*!40000 ALTER TABLE `drug` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `employee`
--

DROP TABLE IF EXISTS `employee`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee` (
  `emp_id` int NOT NULL AUTO_INCREMENT,
  `pharmacist_id` int DEFAULT NULL,
  `shop_id` int DEFAULT NULL,
  PRIMARY KEY (`emp_id`),
  KEY `fk_pharmacist_id` (`pharmacist_id`),
  KEY `fk_working_shop_id` (`shop_id`),
  CONSTRAINT `fk_pharmacist_id` FOREIGN KEY (`pharmacist_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_working_shop_id` FOREIGN KEY (`shop_id`) REFERENCES `shop` (`shop_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `employee`
--

LOCK TABLES `employee` WRITE;
/*!40000 ALTER TABLE `employee` DISABLE KEYS */;
INSERT INTO `employee` VALUES (1,16,1),(2,10,2),(3,8,NULL),(4,3,12),(5,7,5),(6,6,6),(7,11,7),(8,15,NULL),(9,13,1),(10,9,NULL),(11,4,NULL),(12,14,4),(13,5,5),(15,12,7),(16,17,1),(22,23,1),(23,1,14);
/*!40000 ALTER TABLE `employee` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `manufacturer`
--

DROP TABLE IF EXISTS `manufacturer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `manufacturer` (
  `manufacturer_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `address` varchar(50) NOT NULL,
  `phone` varchar(50) NOT NULL,
  `email` varchar(50) NOT NULL,
  `license` varchar(50) NOT NULL,
  `password` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`manufacturer_id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=58 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `manufacturer`
--

LOCK TABLES `manufacturer` WRITE;
/*!40000 ALTER TABLE `manufacturer` DISABLE KEYS */;
INSERT INTO `manufacturer` VALUES (27,'Medix Pharma','Mumbai, MH','9876543210','contact@medix.com','LIC-MX001','$2b$10$mUbkCSVorohsMEh0VIiUvu/mzTIljtUGn.FQBOymXLXqpj0c/Khq.'),(28,'BioCure Labs','Bengaluru, KA','9845123456','info@biocurelabs.com','LIC-BC002','$2b$10$zGcv7Pl148Qd9Ick.qFkVOpVUzXOaNnXGVj9o37ibSjS2eMNg6gdC'),(29,'Zenith Remedies','Delhi, DL','9812345678','support@zenithrem.com','LIC-ZR003','$2b$10$msQuI6gL.7hhnjl6K3RO7ukR2T/mXWDLlsaUn/j7J4qARO2k4yVYC'),(30,'NovaGen Pharma','Hyderabad, TS','9908765432','hello@novagenpharma.com','LIC-NG004','$2b$10$aEOSnpUQeknjfgyPzRsjnupkAIeW6epSc7Bjd7MDiMXEDc8BE1T8S'),(31,'CureWell Ltd','Chennai, TN','9797979797','sales@curewell.com','LIC-CW005','$2b$10$BpyCsrKnbxzrlRm8dJBNHen6BApDZJuBQ4cCWjL67W2tdmRRYtg/a'),(32,'Healix Biotech','Pune, MH','9823456789','contact@healixbio.com','LIC-HB006','$2b$10$bTHGbKwfJzJp5QrYDox9u.2kf0KvuXAYt7k88LQOILc0UD4wCIjIy'),(33,'Trident Meds','Kolkata, WB','9834567890','info@tridentmeds.com','LIC-TM007','$2b$10$olyhiSCd0ZB5pTAdkVWquOyCEm5PE5c/RoBzu7trLSG29dFMUpeFu'),(34,'Apex Therapeutics','Ahmedabad, GJ','9845678901','apex@therapeutics.com','LIC-AT008','$2b$10$syRCaIy.kmWAeYS0SvA7p.A6pnVtPk6PUzpTyA9J2n15nmfvuFB4m'),(35,'Orion Labs','Jaipur, RJ','9856789012','orion@labs.com','LIC-OL009','$2b$10$XqlTFGXcKnGriAoqJKVm4u5WvG/wNFRUJTmrWi5.d4ZvpspI5ikSu'),(36,'VitalCore Pharma','Lucknow, UP','9867890123','vital@corepharma.com','LIC-VP010','$2b$10$RCWgRiSHbAc0lEEOsLfskuDJa7T7LbBSXItgIvaE23zJS.AxVhxC.'),(37,'MedSure Pvt Ltd','Bhopal, MP','9878901234','info@medsure.com','LIC-MS011','$2b$10$aLK7mlX9dERb.Gx0ZHD6nu7HnGCMhr4h6DS5xDxr31DLAbxFY/hdC'),(38,'Genova Remedies','Kochi, KL','9889012345','genova@remedies.com','LIC-GR012','$2b$10$MoVVlWO/ECWKFDe.GVqEzOQnMyjnFBPpDYYegIyvzA/pPZCyI5xvy'),(39,'BioNova Inc','Chandigarh, CH','9890123456','contact@bionova.com','LIC-BN013','$2b$10$mAgPwdZgdvlETBVZt2brk.JDoUqNolP5FiAz2dqh/sz1ZoPvH.Ykq'),(40,'PharmaNest','Nagpur, MH','9901234567','nest@pharma.com','LIC-PN014','$2b$10$HhGD9Zgh9Ee0AOYp89KjjO2BERuYp15GJi6mV7bRaQMF1UHoXoA3i'),(41,'MediTrust Labs','Indore, MP','9912345678','trust@medilabs.com','LIC-MT015','$2b$10$NmEm1s471VWCFUl19t9HrujJsZhSnS5bsO/p7HUf1654R0VZ27OR.'),(42,'CureX Solutions','Surat, GJ','9923456789','curex@solutions.com','LIC-CS016','$2b$10$3ZPZqyq1od2L0LfMzbWxlOGb0KdFqXuFNTnL7C4SE0Tw5IYYBRMMi'),(43,'RxGen Pharma','Patna, BR','9934567890','rxgen@pharma.com','LIC-RP017','$2b$10$AnDpxvjdRncw6txXrxDoae9J106qc.qQ7Y4ssPvTmHZQWFBF8guKS'),(44,'LifeSpan Biotech','Guwahati, AS','9945678901','lifespan@biotech.com','LIC-LB018','$2b$10$B7wd12gifOa9zNhzq5Q0ZOhAR.Zqri6TwWLfMoKWnSoDr8sVu.mZi'),(45,'MediNova Remedies','Mysuru, KA','9956789012','medinova@remedies.com','LIC-MR019','$2b$10$JlD7kWPjZj/lPao15HkQ6.GmioMcaq24wzzEMfrSORxMjiGY03pIi'),(46,'BioSphere Labs','Thiruvananthapuram, KL','9967890123','biosphere@labs.com','LIC-BS020','$2b$10$1.qznSNhsdZOzGSMRb1ieOQipwI6gT1cFaSC0Q96/uAz23jKFofq6'),(47,'GlobeMed Pharma','Visakhapatnam, AP','9978901234','globemed@pharma.com','LIC-GM021','$2b$10$iFicTYHIBkPuRcYVCiUDa.XH4JkyNJ2Z3i42EHfKkFOG3nByDo07m'),(48,'NeoCure Labs','Ranchi, JH','9989012345','neocure@labs.com','LIC-NC022','$2b$10$6t8TpfUmt.76gwICKL8kpeKbxOCWti3AhKJoLj24io6soirI0Teiy'),(49,'AstraWell Biotech','Kanpur, UP','9990123456','astrawell@biotech.com','LIC-AW023','$2b$10$kYuqFbvqjI1ltWljlt83mOAIxvME9dks4XLsWuKhkzTmUZu6zleCm'),(50,'PureLife Remedies','Rajkot, GJ','9971234567','purelife@remedies.com','LIC-PL024','$2b$10$IVD0y3Yybo8PCdxHRzWBtuYCPmJxlA9xwbs0Q3R7mHwgSUJsNQTNS'),(51,'MediCore Pvt Ltd','Coimbatore, TN','9962345678','medicore@pvt.com','LIC-MC025','$2b$10$jLPjA22Lqp.lT4lW7i122esGajqz49Jn9TcoQaIhgew/.RUICoeuC'),(52,'Innova Meds','Varanasi, UP','9953456789','innova@meds.com','LIC-IM026','$2b$10$amtCybKnvsqqpYXbg.jLjeoQZaGXqM0fHwdno.Wu0XfeTpR2KkRBy'),(53,'WellCare Therapeutics','Amritsar, PB','9944567890','wellcare@thera.com','LIC-WT027','$2b$10$8jIE6yuI6JxtntC4EOIl0uNdhFuYNsAl/MZpBenGOuYGaA9y44lCG'),(54,'PharmaLink Ltd','Dehradun, UK','9935678901','pharmalink@ltd.com','LIC-PL028','$2b$10$MDNOTvZSZW436fGEkR74s.Km0i6/8d9HDWIIUHzvgmDlQWlHDqbd2'),(55,'TruHealth Biopharma','Shillong, ML','9926789012','truhealth@bio.com','LIC-TH029','$2b$10$yBMSYJrfbhdzZceiU.yNy.hyqoXtKRoA7uu5ijsSxtIKN3THIviOO'),(56,'NextGen Remedies','Jodhpur, RJ','9917890123','nextgen@remedies.com','LIC-NR030','$2b$10$yLP3uPByvQjXBCBXub3k6OrmTxbnx91PfJnb6H0CyClg4h1kbgy6i'),(57,'Himalaya','Bannerghatta road, Bengaluru, 560002','4567891209','himalaya@herb.com','IGF343432','$2b$10$2FY7ECS/xQC3Q/rEKroVH.AB36j1asXT5YeAjYm3rz9H5THhOJP/C');
/*!40000 ALTER TABLE `manufacturer` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `message_reactions`
--

DROP TABLE IF EXISTS `message_reactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_reactions` (
  `reaction_id` int NOT NULL AUTO_INCREMENT,
  `message_id` int NOT NULL,
  `pharmacist_id` int NOT NULL,
  `emoji` varchar(10) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`reaction_id`),
  UNIQUE KEY `unique_reaction` (`message_id`,`pharmacist_id`),
  KEY `pharmacist_id` (`pharmacist_id`),
  CONSTRAINT `message_reactions_ibfk_1` FOREIGN KEY (`message_id`) REFERENCES `chat_messages` (`message_id`) ON DELETE CASCADE,
  CONSTRAINT `message_reactions_ibfk_2` FOREIGN KEY (`pharmacist_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `message_reactions`
--

LOCK TABLES `message_reactions` WRITE;
/*!40000 ALTER TABLE `message_reactions` DISABLE KEYS */;
/*!40000 ALTER TABLE `message_reactions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `message_read_status`
--

DROP TABLE IF EXISTS `message_read_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_read_status` (
  `read_id` int NOT NULL AUTO_INCREMENT,
  `message_id` int NOT NULL,
  `pharmacist_id` int NOT NULL,
  `read_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`read_id`),
  UNIQUE KEY `unique_read` (`message_id`,`pharmacist_id`),
  KEY `pharmacist_id` (`pharmacist_id`),
  KEY `idx_message_read_status_message` (`message_id`),
  CONSTRAINT `message_read_status_ibfk_1` FOREIGN KEY (`message_id`) REFERENCES `chat_messages` (`message_id`) ON DELETE CASCADE,
  CONSTRAINT `message_read_status_ibfk_2` FOREIGN KEY (`pharmacist_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `message_read_status`
--

LOCK TABLES `message_read_status` WRITE;
/*!40000 ALTER TABLE `message_read_status` DISABLE KEYS */;
/*!40000 ALTER TABLE `message_read_status` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `online_users`
--

DROP TABLE IF EXISTS `online_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `online_users` (
  `pharmacist_id` int NOT NULL,
  `socket_id` varchar(100) NOT NULL,
  `last_seen` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `status` varchar(20) DEFAULT NULL,
  `current_room_id` int DEFAULT NULL,
  PRIMARY KEY (`pharmacist_id`),
  KEY `current_room_id` (`current_room_id`),
  KEY `idx_online_users_status` (`status`),
  CONSTRAINT `online_users_ibfk_1` FOREIGN KEY (`pharmacist_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE CASCADE,
  CONSTRAINT `online_users_ibfk_2` FOREIGN KEY (`current_room_id`) REFERENCES `chat_rooms` (`room_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `online_users`
--

LOCK TABLES `online_users` WRITE;
/*!40000 ALTER TABLE `online_users` DISABLE KEYS */;
INSERT INTO `online_users` VALUES (17,'T2b6KXHx4x5bYSp1AAAB','2025-09-19 16:29:32','online',NULL),(23,'6UrH_fS-UUkKrH5xAAAN','2025-09-19 04:12:32','offline',NULL);
/*!40000 ALTER TABLE `online_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pharmacist`
--

DROP TABLE IF EXISTS `pharmacist`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pharmacist` (
  `pharmacist_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `dob` date DEFAULT NULL,
  `address` varchar(100) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `password` varchar(255) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `refreshToken` text,
  `joined_date` date NOT NULL DEFAULT (curdate()),
  PRIMARY KEY (`pharmacist_id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pharmacist`
--



--
-- Table structure for table `quantity`
--

DROP TABLE IF EXISTS `quantity`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `quantity` (
  `drug_id` int DEFAULT NULL,
  `shop_id` int DEFAULT NULL,
  `quantity` int NOT NULL DEFAULT '0',
  UNIQUE KEY `drug_id` (`drug_id`,`shop_id`),
  KEY `shop_id` (`shop_id`),
  CONSTRAINT `quantity_ibfk_1` FOREIGN KEY (`drug_id`) REFERENCES `drug` (`drug_id`) ON DELETE CASCADE,
  CONSTRAINT `quantity_ibfk_2` FOREIGN KEY (`shop_id`) REFERENCES `shop` (`shop_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quantity`
--

LOCK TABLES `quantity` WRITE;
/*!40000 ALTER TABLE `quantity` DISABLE KEYS */;
INSERT INTO `quantity` VALUES (61,1,70),(62,2,75),(64,4,90),(65,5,60),(66,6,30),(67,7,120),(69,1,0),(70,2,25),(72,4,45),(73,5,85),(74,6,35),(75,7,95),(77,1,79),(78,2,65),(80,4,50),(81,5,75),(82,6,95),(83,7,25),(85,1,130),(86,2,40),(88,4,105),(89,5,55),(90,6,80),(74,1,65),(78,1,36),(83,1,52),(67,1,76);
/*!40000 ALTER TABLE `quantity` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `salary`
--

DROP TABLE IF EXISTS `salary`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `salary` (
  `salary_id` int NOT NULL AUTO_INCREMENT,
  `salary` double NOT NULL DEFAULT '0',
  `emp_id` int NOT NULL,
  PRIMARY KEY (`salary_id`),
  KEY `emp_id` (`emp_id`),
  CONSTRAINT `salary_ibfk_1` FOREIGN KEY (`emp_id`) REFERENCES `employee` (`emp_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `salary`
--

LOCK TABLES `salary` WRITE;
/*!40000 ALTER TABLE `salary` DISABLE KEYS */;
INSERT INTO `salary` VALUES (1,32000,1),(2,28000,2),(3,35000,3),(4,30000,4),(5,27000,5),(6,40000,6),(7,31000,7),(8,36000,8),(9,28000,9),(10,18000,10),(11,25000,11),(12,31000,12),(13,34000,13),(15,38000,15),(16,80000,16),(22,0,22),(23,0,23);
/*!40000 ALTER TABLE `salary` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sale`
--

DROP TABLE IF EXISTS `sale`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sale` (
  `sale_id` int NOT NULL AUTO_INCREMENT,
  `date` datetime DEFAULT CURRENT_TIMESTAMP,
  `shop_id` int NOT NULL,
  `pharmacist_id` int DEFAULT NULL,
  `discount` int DEFAULT '0',
  `customer_id` int DEFAULT NULL,
  PRIMARY KEY (`sale_id`),
  KEY `fk_shop_id` (`shop_id`),
  KEY `fk_sale_pharmacist` (`pharmacist_id`),
  KEY `fk_sale_customer` (`customer_id`),
  CONSTRAINT `fk_sale_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer` (`customer_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sale_pharmacist` FOREIGN KEY (`pharmacist_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_shop_id` FOREIGN KEY (`shop_id`) REFERENCES `shop` (`shop_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=52 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sale`
--

LOCK TABLES `sale` WRITE;
/*!40000 ALTER TABLE `sale` DISABLE KEYS */;
INSERT INTO `sale` VALUES (3,'2025-08-02 09:45:00',1,17,0,1),(4,'2025-08-02 14:30:00',5,5,0,15),(5,'2025-08-03 12:10:00',2,9,0,8),(6,'2025-08-03 16:55:00',6,6,0,18),(7,'2025-08-04 08:25:00',4,14,0,13),(8,'2025-08-04 13:40:00',7,12,0,20),(11,'2025-08-06 10:05:00',1,13,0,2),(12,'2025-08-06 18:20:00',5,7,0,16),(13,'2025-08-07 09:30:00',2,10,0,9),(14,'2025-08-07 14:45:00',6,6,0,19),(15,'2025-08-08 11:55:00',4,3,0,14),(16,'2025-08-08 19:05:00',7,11,0,1),(19,'2025-08-10 09:10:00',1,17,0,3),(20,'2025-08-10 16:35:00',5,7,0,17),(22,'2025-09-08 08:39:46',1,17,10,5),(23,'2025-09-08 08:44:15',1,17,10,6),(24,'2025-09-08 10:59:45',1,17,0,7),(28,'2025-09-08 23:44:44',1,17,1,1),(29,'2025-09-08 23:58:20',1,17,0,25),(30,'2025-09-09 15:32:07',1,17,10,12),(31,'2025-09-09 23:30:34',1,17,10,12),(32,'2025-09-09 23:31:09',1,17,10,4),(33,'2025-09-09 23:40:45',1,17,0,21),(34,'2025-09-10 20:00:21',1,17,10,4),(35,'2025-09-15 23:13:23',1,17,0,21),(36,'2025-09-17 15:00:07',1,17,3,21),(37,'2025-09-17 15:03:36',1,17,2,23),(38,'2025-09-17 15:05:39',1,17,0,21),(39,'2025-09-17 15:09:41',1,17,0,23),(40,'2025-09-17 19:32:37',1,17,0,23),(41,'2025-09-17 19:38:06',1,17,2,24),(42,'2025-09-17 19:47:17',1,17,1,13),(43,'2025-09-17 20:46:14',1,17,10,4),(44,'2025-09-17 20:54:53',1,17,10,4),(45,'2025-09-17 21:00:08',1,17,5,25),(46,'2025-09-17 21:03:14',1,17,0,26),(47,'2025-09-17 21:04:39',1,17,10,4),(48,'2025-09-17 21:12:33',1,17,3,26),(49,'2025-09-17 21:13:33',1,17,0,26),(50,'2025-09-17 21:15:08',1,17,0,24),(51,'2025-09-19 09:13:02',1,17,0,21);
/*!40000 ALTER TABLE `sale` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sale_item`
--

DROP TABLE IF EXISTS `sale_item`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sale_item` (
  `sale_item_id` int NOT NULL AUTO_INCREMENT,
  `sale_id` int DEFAULT NULL,
  `drug_id` int DEFAULT NULL,
  `quantity` int NOT NULL,
  PRIMARY KEY (`sale_item_id`),
  KEY `sale_id` (`sale_id`),
  KEY `drug_id` (`drug_id`),
  CONSTRAINT `sale_item_ibfk_1` FOREIGN KEY (`sale_id`) REFERENCES `sale` (`sale_id`) ON DELETE CASCADE,
  CONSTRAINT `sale_item_ibfk_2` FOREIGN KEY (`drug_id`) REFERENCES `drug` (`drug_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=73 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sale_item`
--

LOCK TABLES `sale_item` WRITE;
/*!40000 ALTER TABLE `sale_item` DISABLE KEYS */;
INSERT INTO `sale_item` VALUES (3,3,67,6),(4,4,70,2),(5,5,90,5),(6,6,68,4),(7,7,62,1),(8,8,84,8),(11,11,76,6),(12,12,88,4),(13,13,64,9),(14,14,82,2),(15,15,66,7),(16,16,86,5),(19,19,89,4),(20,20,78,2),(23,3,74,3),(24,4,83,7),(25,5,65,2),(26,6,79,9),(27,7,77,6),(28,8,71,3),(31,22,61,2),(32,22,69,3),(33,23,61,2),(34,23,69,3),(35,24,61,11),(39,28,69,1),(40,28,61,1),(41,29,61,1),(42,29,69,1),(43,30,61,5),(44,30,69,8),(45,31,61,5),(46,31,69,8),(47,32,61,5),(48,32,69,8),(49,33,61,3),(50,34,77,5),(51,35,77,1),(52,36,74,12),(53,37,74,1),(54,38,69,1),(55,39,74,1),(56,39,69,12),(57,40,74,1),(58,40,69,1),(59,41,83,4),(60,42,69,5),(61,43,77,5),(62,44,77,5),(63,45,67,3),(64,45,83,9),(65,46,74,2),(66,46,69,5),(67,47,77,5),(68,48,74,3),(69,49,69,3),(70,49,74,4),(71,50,69,3),(72,51,69,1);
/*!40000 ALTER TABLE `sale_item` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `shop`
--

DROP TABLE IF EXISTS `shop`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `shop` (
  `shop_id` int NOT NULL AUTO_INCREMENT,
  `address` varchar(50) NOT NULL,
  `phone` varchar(50) NOT NULL,
  `manager_id` int DEFAULT NULL,
  `license` varchar(50) NOT NULL,
  `name` varchar(50) NOT NULL,
  `established` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`shop_id`),
  KEY `fk_manager` (`manager_id`),
  CONSTRAINT `fk_manager` FOREIGN KEY (`manager_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `shop`
--

LOCK TABLES `shop` WRITE;
/*!40000 ALTER TABLE `shop` DISABLE KEYS */;
INSERT INTO `shop` VALUES (1,'MG Road, Bangalore','0801234567',17,'LIC12345','Apollo Pharmacy','2025-09-03 16:19:54'),(2,'KR Puram, Bangalore','0802345678',7,'LIC54321','MedPlus','2025-09-03 16:19:54'),(4,'Whitefield, Bangalore','0804567890',12,'LIC98765','Wellness Pharma','2025-09-03 16:19:54'),(5,'Indiranagar, Bangalore','0805678901',5,'LIC11223','Guardian Pharmacy','2025-09-03 16:19:54'),(6,'Malleshwaram, Bangalore','0806789012',9,'LIC44556','Medico Plus','2025-09-03 16:19:54'),(7,'Koramangala, Bangalore','0807890123',14,'LIC77889','CityCare Pharmacy','2025-09-03 16:19:54'),(12,'Dharmavaram,Telangana','1234567895',3,'LIC98989','Tiranga Pharma','2025-09-17 11:23:03'),(13,'XYZ','123',NULL,'123','XYZ','2025-09-18 15:26:04'),(14,'Bengaluru, RajajiNagar','1234567890',1,'LIC2456','Appolo Pharmacy','2025-09-19 21:51:17');
/*!40000 ALTER TABLE `shop` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `typing_indicators`
--

DROP TABLE IF EXISTS `typing_indicators`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `typing_indicators` (
  `id` int NOT NULL AUTO_INCREMENT,
  `room_id` int NOT NULL,
  `pharmacist_id` int NOT NULL,
  `is_typing` tinyint(1) DEFAULT '1',
  `started_typing_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_typing` (`room_id`,`pharmacist_id`),
  KEY `pharmacist_id` (`pharmacist_id`),
  KEY `idx_typing_indicators_room` (`room_id`),
  CONSTRAINT `typing_indicators_ibfk_1` FOREIGN KEY (`room_id`) REFERENCES `chat_rooms` (`room_id`) ON DELETE CASCADE,
  CONSTRAINT `typing_indicators_ibfk_2` FOREIGN KEY (`pharmacist_id`) REFERENCES `pharmacist` (`pharmacist_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=27 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `typing_indicators`
--

LOCK TABLES `typing_indicators` WRITE;
/*!40000 ALTER TABLE `typing_indicators` DISABLE KEYS */;
/*!40000 ALTER TABLE `typing_indicators` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-09-19 22:05:44
