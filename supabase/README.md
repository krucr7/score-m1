# ติดตั้ง Supabase สำหรับระบบคะแนน ม.1

## A. สร้างโปรเจกต์แยก
ใช้ Supabase project แยกสำหรับระบบคะแนนนี้ ไม่ใช้โปรเจกต์อาหารเช้าหรือระบบกลับหอ เพราะแต่ละโปรเจกต์อาจมีตาราง `students` ที่มีความหมายต่างกัน

## B. สร้างตาราง
1. เปิด Supabase Dashboard ของโปรเจกต์คะแนน
2. เลือก **SQL Editor → New query**
3. วางเนื้อหาไฟล์ `supabase/schema.sql` แล้ว Run
4. ตรวจใน Table Editor ว่าตาราง `students` มี `student_code`, `full_name`, `classroom_id`, `pin_hash`

คำแปลชื่อคอลัมน์:
- `student_code` = รหัสนักเรียน
- `full_name` = ชื่อ-นามสกุล

หน้าเว็บส่งฟิลด์เหล่านี้ลงฐานข้อมูลโดยตรง ไม่จำเป็นต้องสร้างคอลัมน์ภาษาไทย หากเห็นข้อผิดพลาดเรื่องคอลัมน์ ให้รัน schema ในโปรเจกต์คะแนนแล้วรีเฟรชหน้าเว็บ

## C. เปิดสิทธิ์บัญชีครู
1. ไปที่ **Authentication → Users → Add user** และสร้างบัญชีครู
2. คัดลอก UUID ของผู้ใช้
3. เปิด SQL Editor แล้วรันคำสั่ง โดยแทน UUID ให้เป็นค่าจริง:

```sql
insert into public.profiles (user_id, full_name, role)
values ('USER-UUID-จาก-Authentication', 'ครูภูวเนศ อิทธิสิริศักดิ์', 'teacher')
on conflict (user_id) do update
set full_name = excluded.full_name, role = excluded.role;
```

บทบาท `teacher` จัดการเฉพาะห้องที่ครูสร้างเอง บทบาทถูกจัดการจาก SQL Editor ของผู้ดูแล ไม่ให้เปลี่ยนสิทธิ์จากหน้าเว็บ

## D. Deploy Edge Functions
ติดตั้ง [Supabase CLI](https://supabase.com/docs/guides/cli) แล้วรันจากโฟลเดอร์โปรเจกต์:
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy set-student-pin
supabase functions deploy student-score-lookup
``

`student-score-lookup` เปิดให้เรียกแบบสาธารณะเพื่อให้นักเรียนค้นคะแนนได้ แต่ตรวจ PIN ฝั่ง server, จำกัดจำนวนครั้งที่เรียก และส่งคืนเฉพาะรายการประเมินที่ครูเผยแพร่แล้ว ส่วน `set-student-pin` ต้องมีเซสชันครูที่ผ่านการยืนยัน

ห้ามใส่ `SUPABASE_SERVICE_ROLE_KEY` หรือ secret key ลงในไฟล์เว็บหรือ commit ลง GitHub เด็ดขาด ให้ใช้เฉพาะ Environment Secrets ของ Supabase Edge Functions เท่านั้น

## E. ตั้งค่าเว็บ
แก้ `config.js` ให้เป็น Project URL กับ Publishable key จาก **Project Settings → API Keys** เท่านั้น แล้ว commit และ push ไปยัง branch `main`

ใน GitHub repository ให้เปิด **Settings → Pages → Build and deployment → Source: GitHub Actions** เพื่อใช้ workflow ใน `.github/workflows/pages.yml`
