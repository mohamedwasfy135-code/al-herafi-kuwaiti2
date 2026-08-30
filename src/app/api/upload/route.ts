import { NextRequest, NextResponse } from 'next/server';
import { writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import path from 'path';
import { getSessionFromRequest } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    // 1. التحقق من الهوية
    const session = await getSessionFromRequest(request);
    if (!session || session.role !== 'craftsman') {
      return NextResponse.json({ error: 'غير مصرح - يجب تسجيل الدخول كحرفي' }, { status: 401 });
    }

    // 2. قراءة الملف
    let formData;
    try {
      formData = await request.formData();
    } catch (err) {
      console.error('خطأ في قراءة formData:', err);
      return NextResponse.json({ error: 'فشل في قراءة البيانات المرفوعة' }, { status: 400 });
    }

    const file = formData.get('file') as File | null;

    if (!file) {
      return NextResponse.json({ error: 'لم يتم رفع أي ملف' }, { status: 400 });
    }

    // 3. التحقق من نوع الملف
    if (!file.type.startsWith('image/')) {
      return NextResponse.json({ error: 'يجب رفع صورة فقط' }, { status: 400 });
    }

    // 4. التحقق من الحجم (أقصى 5MB)
    if (file.size > 5 * 1024 * 1024) {
      return NextResponse.json({ error: 'حجم الصورة يجب أن يكون أقل من 5MB' }, { status: 400 });
    }

    // 5. إنشاء مجلد الرفع
    const uploadDir = path.join(process.cwd(), 'public', 'uploads', 'documents');
    try {
      if (!existsSync(uploadDir)) {
        await mkdir(uploadDir, { recursive: true });
      }
    } catch (err) {
      console.error('خطأ في إنشاء المجلد:', err);
      return NextResponse.json({ error: 'فشل في إنشاء مجلد الرفع' }, { status: 500 });
    }

    // 6. إنشاء اسم ملف فريد
    const bytes = await file.arrayBuffer();
    const buffer = Buffer.from(bytes);
    
    // استخراج الامتداد من اسم الملف
    const originalName = file.name || 'image.jpg';
    const fileExtension = originalName.split('.').pop() || 'jpg';
    const safeExtension = ['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(fileExtension.toLowerCase()) 
      ? fileExtension.toLowerCase() 
      : 'jpg';
    
    const uniqueName = `craftsman-${session.userId}-${Date.now()}.${safeExtension}`;
    const filePath = path.join(uploadDir, uniqueName);

    // 7. حفظ الملف
    try {
      await writeFile(filePath, buffer);
    } catch (err) {
      console.error('خطأ في حفظ الملف:', err);
      return NextResponse.json({ error: 'فشل في حفظ الصورة' }, { status: 500 });
    }

    // 8. إرجاع الرابط
    const fileUrl = `/uploads/documents/${uniqueName}`;

    return NextResponse.json({ 
      success: true, 
      url: fileUrl,
      message: 'تم رفع الصورة بنجاح' 
    });
  } catch (error: any) {
    console.error('❌ خطأ في Upload API:', error);
    return NextResponse.json({ 
      error: 'حدث خطأ في رفع الملف',
      details: error.message 
    }, { status: 500 });
  }
}
