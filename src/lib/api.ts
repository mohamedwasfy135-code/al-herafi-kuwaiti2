// src/lib/api.ts
// دوال وهمية (mock) لتمكين الصفحة من العمل.
// يمكنك استبدال هذه الدوال لاحقاً باستدعاءات API الحقيقية من مشروعك.

export async function getAvailableRequestsForBidding() {
    // TODO: استبدل هذا باستدعاء API الفعلي لجلب الطلبات المتاحة للتسعير
    console.warn("⚠️ استخدام بيانات وهمية getAvailableRequestsForBidding - يرجى التعديل");
    return [];
}

export async function submitOffer(requestId: number, data: any) {
    // TODO: استبدل هذا باستدعاء API الفعلي لتقديم عرض سعر
    console.warn(`⚠️ استخدام بيانات وهمية submitOffer للطلب ${requestId} - يرجى التعديل`, data);
    return { success: true, message: "تم إرسال العرض بنجاح (بيانات وهمية)" };
}

export async function getMyOffers() {
    // TODO: استبدل هذا باستدعاء API الفعلي لجلب عروض الحرفي
    console.warn("⚠️ استخدام بيانات وهمية getMyOffers - يرجى التعديل");
    return [];
}

export async function uploadDocument(file: any) {
    // TODO: استبدل هذا باستدعاء API الفعلي لرفع المستندات
    console.warn(`⚠️ استخدام بيانات وهمية uploadDocument - يرجى التعديل`, file);
    return { success: true, message: "تم رفع المستند بنجاح (بيانات وهمية)" };
}
