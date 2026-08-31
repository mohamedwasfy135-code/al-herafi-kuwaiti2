import { db } from '@/lib/db';

export async function validateCraftsmanSubscription(userId: string) {
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { 
      role: true, 
      subscriptionStatus: true, 
      subscriptionExpiryDate: true 
    }
  });

  if (!user || user.role !== 'craftsman') {
    return { isValid: false, error: 'غير مصرح', status: 401 };
  }

  const now = new Date();
  
  // إذا لم يكن نشطاً أو انتهى تاريخ الصلاحية
  if (user.subscriptionStatus !== 'active' || (user.subscriptionExpiryDate && user.subscriptionExpiryDate < now)) {
    // تحديث الحالة تلقائياً إلى منتهي إذا لزم الأمر
    if (user.subscriptionStatus === 'active') {
      await db.user.update({
        where: { id: userId },
        data: { subscriptionStatus: 'expired' }
      });
    }
    return { 
      isValid: false, 
      error: 'اشتراكك منتهي. يرجى تجديد الاشتراك لمواصلة استقبال الطلبات.', 
      status: 403 
    };
  }

  return { isValid: true, user };
}
