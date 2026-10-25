# ระบบเก็บคะแนนนักเรียน ม.1 — ครูภูวเนศ อิทธิสิริศักดิ์

โปรเจกต์นี้เป็นเว็บคะแนนนักเรียนแบบออนไลน์ ใช้ GitHub Pages สำหรับหน้าเว็บและ Supabase สำหรับฐานข้อมูล

## สถานะ
- มีหน้าค้นหาคะแนนนักเรียนด้วยรหัสและ PIN
- มีส่วนครูสำหรับเข้าสู่ระบบ จัดการห้องเรียน นักเรียน รายการประเมิน และคะแนน
- นำเข้ารายชื่อนักเรียนจาก CSV โดยรองรับ comma, semicolon และ tab และรองรับชื่อหัวตารางไทยที่มีขีดหลายแบบ
- ต้องติดตั้ง SQL, Deploy Edge Functions และกำหนด config.js ก่อนใช้งานข้อมูลจริง

## ตั้งค่า Supabase
1. สร้าง Supabase project ใหม่สำหรับระบบคะแนนโดยเฉพาะ อย่าใช้ project อาหารเช้าหรือระบบลงชื่อกลับบ้าน
2. เปิด SQL Editor แล้วรันไฟล์ `supabase/schema.sql`
3. สร้างบัญชีครูใน Authentication > Users แล้วใช้ SQL ที่แสดงในเอกสารตั้ง role เป็น admin
4. Deploy functions ตามคู่มือใน `supabase/README.md`
5. แก้ `config.js` ให้มี Project URL และ Publishable key เท่านั้น ห้ามใส่ service_role/secret key ในหน้าเว็บ

## เผยแพร่ GitHub Pages
ใน GitHub repository ไปที่ Settings > Pages แล้วเลือก Build and deployment > Source = GitHub Actions เมื่อ push ไฟล์แล้ว workflow จะ deploy ไฟล์เว็บให้อัตโนมัติ

## ความปลอดภัย
- ห้ามเก็บ Service Role/Secret key ใน `index.html` หรือ `config.js`
- อย่าเปิดข้อมูลคะแนนสาธารณะโดยตรง ตารางควรมี RLS และนักเรียนค้นคะแนนผ่าน Edge Function ที่ตรวจ PIN ฝั่ง server
- ทดสอบด้วยข้อมูลสมมติก่อนใช้ข้อมูลจริงของนักเรียน
