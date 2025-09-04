# Dev Setup Docker

สคริปต์ PowerShell สำหรับติดตั้งและตั้งค่า **Docker Desktop + WSL2** บน Windows ให้พร้อมใช้งานได้ทันที  
เหมาะสำหรับนักพัฒนา (dev) ที่ต้องการเซ็ตอัพเครื่องใหม่อย่างรวดเร็วโดยไม่ต้องลงทุกอย่างเองทีละขั้น

---

## ⚙️ Features
สคริปต์นี้จะทำให้คุณ:
- เปิดใช้งาน **WSL2** และ Virtual Machine Platform บน Windows
- ตั้งค่า WSL ให้ใช้ **version 2** เป็นค่าเริ่มต้น
- ติดตั้ง **Ubuntu 22.04** (ถ้ายังไม่มีดิสโทรในเครื่อง)
- ติดตั้ง/อัปเกรด **Docker Desktop** ผ่าน `winget`
- เพิ่มผู้ใช้ปัจจุบันเข้า group `docker-users`
- รันทดสอบ `docker run hello-world` ให้อัตโนมัติ (smoke test)

---

## 🚀 วิธีใช้งาน

1. **เปิด PowerShell แบบ Run as Administrator**  
   - คลิกปุ่ม Start → พิมพ์ `PowerShell` → คลิกขวา → เลือก **Run as Administrator**

2. **อนุญาตการรันสคริปต์เฉพาะครั้งนี้**  
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

3. **ไปยังโฟลเดอร์ที่เก็บสคริปต์และรัน**  
   ```powershell
   cd C:\Users\admin\Downloads
   .\setup-docker.ps1
   ```

4. **รีสตาร์ทถ้าระบบแจ้ง**  
   - หากมีข้อความว่าต้องรีสตาร์ท ให้รีสตาร์ทเครื่อง แล้วเปิด PowerShell (Admin) มารันสคริปต์ซ้ำ  
   - สคริปต์จะ “ข้ามส่วนที่ทำไปแล้ว” และทำงานต่อจากจุดค้าง

5. **ทดสอบหลังติดตั้ง**  
   ```powershell
   docker run --rm hello-world
   ```

---

## 🖥️ การตรวจสอบสถานะ WSL
หลังรีสตาร์ท สามารถตรวจสอบได้ว่า WSL พร้อมหรือยัง:
```powershell
wsl -l -v       # แสดงรายชื่อดิสโทร และเวอร์ชัน (ต้องเป็น VERSION 2)
wsl --status    # แสดงสถานะ kernel และ default version
```

ถ้ายังไม่เห็น Ubuntu หรือขึ้นว่า “no installed distributions” ให้ติดตั้งเองด้วย:
```powershell
wsl --install -d Ubuntu-22.04
```

---

## 🔧 การแก้ปัญหาที่พบบ่อย

### 1. `0x80370102` – Virtualization ไม่เปิด
- แก้โดยเข้า BIOS/UEFI → เปิด **Intel VT-x** หรือ **AMD SVM Mode**
- ตรวจสอบได้ใน Task Manager → Performance → CPU → ต้องเห็น `Virtualization: Enabled`

### 2. สคริปต์บอกว่า `requires elevation`
- แปลว่าคุณไม่ได้เปิด PowerShell แบบ **Run as Administrator**

### 3. สคริปต์เปิด Notepad แทนที่จะรัน
- เพราะไม่ได้รันจาก PowerShell แต่เป็น CMD → ให้คลิกขวาที่ไฟล์เลือก **Run with PowerShell** หรือเปิด PowerShell (Admin) แล้วสั่ง `.\setup-docker.ps1`

### 4. Docker รันไม่ขึ้นหลังติดตั้ง
- เปิด Docker Desktop หนึ่งครั้ง แล้วไปที่ **Settings > Resources > WSL integration** ให้เปิดใช้งานดิสโทรที่ต้องการ
- จากนั้นลองใหม่:
  ```powershell
  docker run --rm hello-world
  ```

---

## 📌 หมายเหตุ
- ต้องมี `winget` (App Installer) จาก Microsoft Store
- ต้องเปิด **Virtual Machine Platform** และ **WSL2** ก่อน Docker จะทำงาน
- สคริปต์นี้ปลอดภัยที่จะรันซ้ำ (idempotent) → ไม่ต้องกลัวทำซ้ำแล้วพัง
- ถ้าใช้ Windows Pro/Enterprise และอยากเปิด Hyper-V เพิ่มเติม ให้รัน:
  ```powershell
  .\setup-docker.ps1 -EnableHyperV
  ```

---

## ✅ สรุป
เมื่อทำตามครบ คุณจะได้:
- WSL2 พร้อม Ubuntu 22.04
- Docker Desktop ติดตั้งแล้ว
- ผู้ใช้ปัจจุบันอยู่ในกลุ่ม `docker-users`
- สามารถรัน `docker run hello-world` ได้ทันที
