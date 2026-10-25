# ระบบเก็บคะแนนนักเรียน ม.1 — ครูภูวเนศ อิทธิสิริศักดิ์

ระบบนี้เผยแพร่หน้าเว็บผ่าน GitHub Pages และใช้ Supabase PostgreSQL เป็นฐานข้อมูล

## 1. ตั้งค่า Supabase (ควรใช้โปรเจกต์แยกสำหรับระบบคะแนน)
1. สร้าง Supabase project แยกจากระบบอาหาร/ระบบกลับบ้าน
2. เปิด SQL Editor แล้ววางและรันไฟล์ `supabase/schema.sql`
3. ไปที่ **Project Settings → API Keys** แล้วคัดลอก Project URL กับ **Publishable key** (หรือ anon key เดิม)
4. แก้ไฟล์ `config.js` ใน GitHub โดยใส่ค่าจริง:
   - `SUPABASE_URL`: Project URL
   - `SUPABASE_PUBLISHABLE_KEY`: publishable/anon key เท่านั้น
   - **ห้าม** ใส่ service_role/secret key ใน `config.js`

## 2. สร้างบัญชีครู
1. ใน Supabase เปิด **Authentication → Users → Add user** แล้วสร้างบัญชีครูด้วยอีเมลและรหัสผ่าน
2. คัดลอก User UID ของบัญชีนั้น
3. ใน SQL Editor รันคำสั่งนี้ โดยแทนที่ UID และชื่อด้วยข้อมูลจริง:

```sql
insert into public.profiles (user_id, full_name, role)
values ('ใส่-USER-UID-ที่นี่', 'ครูภูวเนศ อิทธิสิริศักดิ์', 'teacher')
on conflict (user_id) do update
set full_name = excluded.full_name, role = excluded.role;
```

## 3. Deploy Edge Functions
ใช้ Supabase CLI ในเครื่องที่ติดตั้ง Supabase CLI และล็อกอินแล้ว:
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy set-student-pin
supabase functions deploy student-score-lookup
``
ตั้งค่า function secrets ให้มี `SUPABASE_URL`, `SUPABASE_ANON_KEY` และ `SUPABASE_SERVICE_ROLE_KEY` ตามค่าของโปรเจกต์ ถ้า deploy ผ่าน CLI ของ Supabase โดยตรง ระบบมักใส่ตัวแปรมาตรฐานให้อัตโนมัติ

## 4. เปิด GitHub Pages
1. ไปที่ repository **Settings → Pages**
2. ตั้ง **Build and deployment → Source** เป็น **GitHub Actions**
3. workflow จะเผยแพร่เว็บจาก branch `main`
4. หน้าเว็บจะอยู่ที่ `https://krucr7.github.io/score-m1/`

## ปัญหาเพิ่มนักเรียนไม่ได้
ฟอร์มใช้คอลัมน์จริงดังนี้:
- `student_code` = รหัสนักเรียน
- `full_name` = ชื่อ-นามสกุล
- `classroom_id` = ห้องเรียนที่เลือก

ให้รัน `supabase/schema.sql` ก่อนเพิ่มนักเรียน ถ้าเป็นฐานข้อมูลเก่าที่สร้างตารางไว้บางส่วน SQL มีคำสั่ง `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` เพื่อเพิ่มคอลัมน์ที่ขาด แต่โปรดรันเฉพาะในโปรเจกต์คะแนน ไม่ใช่โปรเจกต์ระบบอื่น

การเพิ่มนักเรียนต้องเลือกห้องเรียน แต่ไม่จำเป็นต้องสร้างวิชาก่อน ถ้ามีข้อความว่าคอลัมน์ไม่ครบ ให้รัน schema แล้วรีเฟรชหน้าเว็บ

## ความปลอดภัย
- RLS จำกัดการจัดการข้อมูลให้อยู่ในห้องที่ครูเป็นเจ้าของ
- นักเรียนใช้ Edge Function ตรวจ PIN แทนการอ่านตารางคะแนนโดยตรง
- ระบบไม่เปิดเผย hash ของ PIN ในหน้าเว็บ
- ต้องใช้ HTTPS และไม่ส่งต่อ PIN ให้ผู้อื่น
