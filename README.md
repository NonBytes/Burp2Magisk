# Burp2Magisk สำหรับ macOS

แอป Swift/AppKit สำหรับเลือกหรือลาก Burp CA certificate (.der/.pem) ได้หลายไฟล์พร้อมกัน ดูตัวอย่าง subject/วันหมดอายุก่อนสร้าง และบันทึก Magisk module ZIP เดียวที่รวมทุก CA โดยใช้ Magisk template ของ Burp2Magisk

![Burp2Magisk macOS](docs/images/macos-app.png)

## ดาวน์โหลด v1.0.1

ดาวน์โหลด [Burp2Magisk-macOS.zip](https://github.com/NonBytes/Burp2Magisk/releases/download/v1.0.1/Burp2Magisk-macOS.zip) จาก [GitHub Releases](https://github.com/NonBytes/Burp2Magisk/releases/latest) สำหรับ **macOS 12 ขึ้นไป บน Apple Silicon (arm64)** ไม่ต้องติดตั้ง Python หรือ Homebrew

## ใช้งาน

1. แตก `Burp2Magisk-macOS.zip` แล้วลาก `Burp2Magisk.app` ไป Applications และเปิดแอป
2. ลาก certificate ลงในหน้าต่าง หรือกด **เลือกไฟล์…**
3. กด **สร้าง Magisk ZIP…** แล้วเลือกที่บันทึก
4. นำ ZIP ผลลัพธ์ไปติดตั้งผ่าน Magisk บน Android แล้ว reboot ด้วยตัวเอง หรือถ้าเชื่อมอุปกรณ์ผ่าน
   USB debugging ไว้ (และอนุญาต root ให้ ADB แล้ว) แอปจะตรวจพบอุปกรณ์หลังสร้าง ZIP สำเร็จ และมีปุ่ม
   **ติดตั้งผ่าน ADB…** ให้กดเพื่อ push และติดตั้งโมดูลให้ทันที — การกดปุ่มนี้คือการยืนยันของคุณเอง
   ไม่มีการเชื่อมต่อหรือ push ใด ๆ เกิดขึ้นถ้าไม่ได้กด และแอปจะไม่สั่ง reboot ให้เองเด็ดขาด (มีปุ่ม
   reboot แยกต่างหากให้กดเองอีกครั้งหลังติดตั้งสำเร็จ ถ้าต้องการ)

รองรับ macOS 12 ขึ้นไป บน Apple Silicon (arm64) รวมไฟล์ที่ต้องใช้ไว้ในแอป ไม่ต้องติดตั้ง Python หรือ Homebrew ใช้ OpenSSL, zip และ unzip ที่มากับ macOS แอปเซ็นแบบ ad hoc สำหรับใช้งานในเครื่อง ยังไม่ได้ notarize สำหรับแจกจ่าย จึงอาจมีการแจ้งเตือนจาก macOS เมื่อส่งต่อ

ตรวจ Basic Constraints ว่าเป็น CA:TRUE ไม่เขียน certificate ลง trust store ของ Mac ไม่ข้ามหรือ
แตะต้อง certificate pinning การรองรับ ROM/Android ต้องทดสอบกับเครื่องเป้าหมาย สคริปต์ต้นแบบมีการ
จัดการ Conscrypt APEX ด้วย bind mounts ฟีเจอร์ติดตั้งผ่าน ADB เป็นทางเลือก (opt-in) ต้องมี Android
SDK Platform Tools (`adb`) ติดตั้งแยกไว้ และต้องกดปุ่มเองทุกครั้ง แอปไม่เชื่อมต่ออุปกรณ์เองโดยอัตโนมัติ

## เปิดแอปครั้งแรก

แอปเซ็นแบบ ad hoc และ **ยังไม่ได้ notarize โดย Apple** หาก macOS แจ้งว่าไม่สามารถยืนยันผู้พัฒนาได้ และคุณตรวจแล้วว่าไฟล์มาจาก Release นี้ ให้ลองเปิดหนึ่งครั้งแล้วไปที่ **System Settings → Privacy & Security → Open Anyway** (macOS 12 ใช้ System Preferences → Security & Privacy → General) จากนั้นตรวจชื่อแอปและยืนยันเปิด เฉพาะแอปนี้ ตาม [คำแนะนำ Apple](https://support.apple.com/en-us/102445)

ไม่ต้องปิด Gatekeeper ทั้งระบบ หากไม่ต้องการอนุญาตแอปที่ยังไม่ได้ notarize สามารถ build จากซอร์สได้

Release มีไฟล์ `SHA256SUMS.txt` สำหรับตรวจว่าไฟล์ดาวน์โหลดตรงกับไฟล์ที่เผยแพร่ ดาวน์โหลดทั้งสองไฟล์ไว้ในโฟลเดอร์เดียวกัน แล้วรัน `shasum -a 256 -c SHA256SUMS.txt`

## Build จากซอร์ส

เปิด `Burp2Magisk.xcodeproj` ด้วย Xcode เลือก scheme **Burp2Magisk** และปลายทาง **My Mac** แล้วกด **⌘R** โปรเจกต์ไม่มี external dependencies

ต้องมี Xcode Command Line Tools แล้วรัน `bash build.sh` ผลลัพธ์อยู่ใน `dist/` อ่าน [CONTRIBUTING.md](CONTRIBUTING.md) สำหรับโครงสร้างโค้ด วิธีทดสอบ จัดรูปแบบ และสร้างไอคอน

## โครงสร้างโปรเจกต์

```text
Burp2Magisk.xcodeproj/   โปรเจกต์ Xcode
Sources/main.swift        จุดเริ่มต้น AppKit
Sources/App/              วงจรชีวิตแอป
Sources/UI/               หน้าต่าง ธีม และ UI components
Sources/Services/         สร้าง module และบันทึก ZIP แยกจาก GUI
Resources/Info.plist      ข้อมูลแอป
Resources/*.sh            ตรวจ certificate และสร้าง module
Resources/ModuleTemplate/ installer และ boot script ที่อ่านแก้ไขได้
build.sh                  build แอป (arm64) และ ZIP
Tests/                    integration tests ของตัวสร้าง ZIP
scripts/test.sh           รันชุดทดสอบโดยไม่เปิด GUI
```

ก่อนส่งการเปลี่ยนแปลง รัน `bash scripts/test.sh` และ `bash build.sh` จัดรูปแบบ Swift ตาม `.swift-format` ด้วย `xcrun swift-format format --in-place --recursive Sources scripts Tests`

## Git

Repository นี้ไม่รวม certificate, private key, ZIP ต้นฉบับ, executable เดิม, build outputs หรือการตั้งค่า Xcode ของแต่ละคน ตรวจรายการก่อน commit ด้วย `git status` แล้วเพิ่ม source ด้วย `git add .` และ `git commit -m "Initial macOS app project"` จากนั้นตั้ง remote ของคุณและ push

## Magisk template ของ Burp2Magisk

ซอร์สอยู่ใน `Resources/ModuleTemplate/` ใช้ `module.prop` และ `customize.sh` ตาม [Magisk Developer Guide](https://topjohnwu.github.io/Magisk/guides.html) ZIP สำหรับติดตั้งผ่านแอป Magisk เท่านั้น ไม่รองรับ recovery flashing

Legacy system store ใช้ Magisk system overlay ส่วน Conscrypt APEX ใช้สคริปต์ Burp2Magisk ที่ทำ snapshot ของ CA เดิมทั้งหมด แล้วสร้าง tmpfs overlay ใน mount namespace ของ init ช่วง post-fs-data หากเตรียม overlay ไม่สำเร็จจะพยายามถอด mount กลับ ไม่แก้ไฟล์ APEX ต้นฉบับ ตรวจ log ได้ที่ `/data/adb/modules/burp_ca_<hash>/boot.log` ผู้พัฒนาทดสอบ GUI และติดตั้ง/ใช้งาน module บน Android แล้ว แต่ยังไม่ได้ระบุรุ่น Android/ROM ในผลทดสอบ จึงไม่รับรองทุกเครื่อง และไม่มีการอัปเดตอัตโนมัติ

สคริปต์ปัจจุบันเขียนใหม่สำหรับ Burp2Magisk และไม่มีการโหลด template ZIP ภายนอก ประวัติโปรเจกต์เคยใช้ template ของ Reqable/CustomCACert; เก็บข้อความ GPL-3.0 ในโฟลเดอร์ template เพื่อคงเงื่อนไขการแจกจ่ายเดิม
