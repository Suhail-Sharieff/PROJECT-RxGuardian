# 💊 PROJECT — RxGuardian

**RxGuardian** is an advanced **Pharmacy Management System (PMS)** designed to streamline pharmacy operations by providing robust tools for **inventory control, billing, analytics, workforce management, and communication**.  

This repository currently represents the **MVP (Minimum Viable Product)**. Several enterprise-grade features are under active development. 🚀  

---

## 🛠️ Tech Stack
- **Frontend:** Flutter (cross-platform mobile & desktop UI)  
- **Backend:** Node.js (REST API + WebSocket server)  
- **Authentication:** Firebase + JWT (hybrid model for scalability and security)  
- **Database:** MySQL (Oracle-based distribution) with Redis for caching  
- **Real-Time Communication:** Socket.IO  

---

## ✨ Core Features

1. 🔐 **Authentication & Security**  
   - Hybrid Firebase + JWT flow for multi-layered security  
   - Session handling with refresh tokens  

2. 📦 **Inventory & Stock Management**  
   - Real-time stock visibility  
   - Low-stock and expiry alerts  

3. 🧾 **Point of Sale (POS) Console**  
   - Fast, dedicated billing interface  
   - Integrated **customer management module**  

4. 📊 **Business Analytics**  
   - Daily, monthly, and yearly reports  
   - Sales trends, stock consumption, and drug performance  

5. 🛒 **Procurement Panel**  
   - Direct purchase of medicines from manufacturers  
   - Streamlined vendor integration  

6. 🧑‍💼 **Manager Console**  
   - Track employee performance and sales contribution  
   - Remote pharmacist hiring & role-based access  

7. 💬 **Integrated Chat System**  
   - Role-based rooms (e.g., divisions/teams)  
   - Message editing, reactions, and threaded replies  

8. 🤖 **AI-Driven Insights (Planned)**  
   - Predictive analytics for billing, procurement, and hiring  
   - Demand forecasting with anomaly detection  

---

## ⚡ Optimizations
- Optimized SQL queries for performance  
- Transaction-based query failure management  
- **70% faster response time** via Redis caching  
- Secure WebSocket-based chat with Socket.IO  

---

## 📸 Screenshots

### 🖼️ System Overview
<p align="center">

  <img width="4291" height="1881" alt="er drawio" src="https://github.com/user-attachments/assets/aa551615-2f5d-419f-bf23-5baed46db559" />

</p>

---

### 🖥️ Application Screens
<p align="center">
  <img src="https://github.com/user-attachments/assets/a4fdb8b5-187f-47c4-969c-485b9706208a" width="32%" />
  <img src="https://github.com/user-attachments/assets/5a952278-1dfd-4dce-ba40-a1dfcded567a" width="32%" />
  <img src="https://github.com/user-attachments/assets/035c7adb-e54d-426e-8828-24dd1d3404ce" width="32%" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/dfa3435c-708e-47a6-a667-bd2a0283c814" width="32%" />
  <img src="https://github.com/user-attachments/assets/799b8ca9-4483-4591-ad86-afb9339d87ee" width="32%" />
  <img src="https://github.com/user-attachments/assets/daee8200-c528-4c4c-b10a-b1827ac0d23b" width="32%" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/6ba07ec3-8ec0-42ca-8b73-afc8301fbc72" width="32%" />
  <img src="https://github.com/user-attachments/assets/60574422-0e4f-44bb-bc94-e5c9cb52deb5" width="32%" />
  <img src="https://github.com/user-attachments/assets/fee60de6-3781-4f6c-a769-878bf4259a8d" width="32%" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/2e489a6b-28e5-45ce-b636-36cdeec557e0" width="32%" />
  <img src="https://github.com/user-attachments/assets/5a801e47-6648-4edc-b6ae-9bf115b1caae" width="32%" />
  <img src="https://github.com/user-attachments/assets/0cdc7e87-4293-406e-827c-f201caffb421" width="32%" />
</p>
<p>
<img src="https://github.com/user-attachments/assets/04278483-ea17-403e-b5d8-5cdb69882b37" width="32%"  />
<img src="https://github.com/user-attachments/assets/2b22499d-0b83-4009-be87-f4b9d52d5bfd" width="32%"/>

</p>

---

## 🚀 Future Roadmap
- AI-powered demand forecasting  
- Multi-store integration  
- Mobile-friendly dashboards  
- Real-time notifications for stock-outs  
- Integration with medical insurance providers  

---
## Testing locally
- For first time, run `docker compose up --build`
- Now u can run container either in `docker dekstop` or in terminal just run `docker compose up`
- Now just test apis in postman
## 👨‍💻 Contributors
- Built with ❤️ by **Suhail**





