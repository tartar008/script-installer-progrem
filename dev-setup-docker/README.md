# Dev Setup Docker

สคริปต์ PowerShell สำหรับติดตั้งและตั้งค่า **Docker Desktop + WSL2** บน Windows ให้พร้อมใช้งานได้ทันที  
เหมาะสำหรับนักพัฒนา (dev) ที่ต้องการเซ็ตอัพเครื่องใหม่อย่างรวดเร็ว

---

## ⚙️ Features
- เปิดใช้งาน **WSL2** และ Virtual Machine Platform
- ตั้งค่า WSL ให้ใช้ **version 2** เป็นค่าเริ่มต้น
- ติดตั้ง **Ubuntu 22.04** (ถ้ายังไม่มีดิสโทร)
- ติดตั้ง/อัปเกรด **Docker Desktop** ผ่าน `winget`
- เพิ่มผู้ใช้ปัจจุบันเข้า group `docker-users`
- รันทดสอบ `docker run hello-world` ให้อัตโนมัติ

---

## 🚀 วิธีใช้งาน

1. เปิด **PowerShell (Run as Administrator)**
2. อนุญาตการรันสคริปต์เฉพาะครั้งนี้:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
