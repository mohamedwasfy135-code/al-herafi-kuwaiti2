const API_KEY = process.env.MYFATOORAH_API_KEY?.trim();
const BASE_URL = (process.env.MYFATOORAH_BASE_URL || 'https://apitest.myfatoorah.com').replace(/\/+$/, '');

export interface InvoiceItem {
  ItemName: string;
  Quantity: number;
  UnitPrice: number;
}

export interface CreateInvoiceData {
  InvoiceValue: number;
  CustomerName: string;
  CustomerMobile: string;
  CustomerEmail: string;
  CallBackUrl: string;
  ErrorUrl: string;
  InvoiceItems: InvoiceItem[];
}

export async function createInvoice(data: CreateInvoiceData) {
  console.log('🔑 التحقق من مفتاح API:', API_KEY ? `موجود (يبدأ بـ: ${API_KEY.substring(0, 15)}...)` : 'مفقود ❌');
  
  if (!API_KEY) {
    throw new Error('مفتاح MYFATOORAH_API_KEY غير موجود في ملف .env');
  }

  try {
    const payload = {
      InvoiceValue: parseFloat(String(data.InvoiceValue)),
      CustomerName: data.CustomerName || 'عميل',
      DisplayCurrencyIso: "KWD",
      NotificationOption: "LNK",
      MobileCountryCode: 512,
      CustomerMobile: data.CustomerMobile || '00000000',
      CustomerEmail: data.CustomerEmail || 'test@test.com',
      // استخدام رابط وهمي لأن ماي فاتورة تحظر localhost
      CallBackUrl: 'https://example.com/callback',
      ErrorUrl: 'https://example.com/error',
      Language: "ar",
      CustomerReference: `INV-${Date.now()}`,
      InvoiceItems: (data.InvoiceItems && data.InvoiceItems.length > 0) 
        ? data.InvoiceItems.map(item => ({
            ItemName: item.ItemName,
            Quantity: parseInt(String(item.Quantity)),
            UnitPrice: parseFloat(String(item.UnitPrice))
          }))
        : [{ ItemName: 'خدمة', Quantity: 1, UnitPrice: parseFloat(String(data.InvoiceValue)) }],
    };

    const endpoint = `${BASE_URL}/v2/SendPayment`;
    console.log('📤 جاري إرسال الطلب إلى:', endpoint);
    console.log('📦 Payload:', JSON.stringify(payload, null, 2));

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload),
      cache: 'no-store',
    });

    console.log('📊 حالة الاستجابة (Status):', response.status, response.statusText);
    const responseText = await response.text();
    console.log('📥 استجابة الخادم الخام (Raw):', responseText || '(فارغة)');

    if (!responseText) {
      throw new Error(`الخادم أرجع استجابة فارغة. حالة HTTP: ${response.status}`);
    }

    let result;
    try {
      result = JSON.parse(responseText);
    } catch (e) {
      throw new Error(`استجابة غير صالحة من الخادم: ${responseText}`);
    }

    if (!response.ok) {
      throw new Error(result.Message || `خطأ HTTP: ${response.status}`);
    }

    if (result.IsSuccess) {
      console.log('✅ تم إنشاء الفاتورة بنجاح. InvoiceId:', result.Data.InvoiceId);
      console.log('💳 PaymentURL:', result.Data.InvoiceURL);
      return {
        InvoiceId: result.Data.InvoiceId,
        PaymentURL: result.Data.InvoiceURL,
      };
    } else {
      throw new Error(result.Message || 'فشل إنشاء الفاتورة من ماي فاتورة');
    }
  } catch (error: any) {
    console.error('❌ خطأ فادح في ماي فاتورة:', error.message);
    throw error;
  }
}

export async function getInvoiceStatus(invoiceId: string) {
  try {
    const response = await fetch(`${BASE_URL}/v2/GetPaymentStatus?paymentId=${invoiceId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      cache: 'no-store',
    });

    const result = await response.json();
    if (result.IsSuccess) {
      return result.Data;
    } else {
      throw new Error(result.Message || 'فشل جلب الحالة');
    }
  } catch (error: any) {
    console.error('❌ خطأ في جلب حالة الفاتورة:', error.message);
    throw error;
  }
}

export const VISIT_FEE = 3;
