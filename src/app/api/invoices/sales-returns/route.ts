import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const returns = await db.salesReturn.findMany({
      where: { businessId },
      include: {
        originalInvoice: {
          select: { id: true, invoiceNumber: true, clientName: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(returns)
  } catch (error) {
    console.error('[SALES_RETURNS] GET error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      originalInvoiceId,
      returnNumber,
      clientName,
      total,
      reason,
    } = body

    if (!originalInvoiceId || !total) {
      return NextResponse.json(
        { error: 'الفاتورة الأصلية والمبلغ مطلوبان' },
        { status: 400 }
      )
    }

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    // Verify the original invoice exists and belongs to this business
    const invoice = await db.salesInvoice.findFirst({
      where: { id: parseInt(originalInvoiceId), businessId },
    })

    if (!invoice) {
      return NextResponse.json({ error: 'الفاتورة الأصلية غير موجودة' }, { status: 404 })
    }

    const salesReturn = await db.salesReturn.create({
      data: {
        businessId,
        originalInvoiceId: parseInt(originalInvoiceId),
        returnNumber: returnNumber || `SR-${Date.now()}`,
        clientName: clientName || invoice.clientName,
        total: parseFloat(String(total)),
        reason: reason || null,
        status: 'pending',
      },
      include: {
        originalInvoice: {
          select: { id: true, invoiceNumber: true, clientName: true },
        },
      },
    })

    return NextResponse.json(salesReturn, { status: 201 })
  } catch (error) {
    console.error('[SALES_RETURNS] POST error:', error)
    return NextResponse.json({ error: 'حدث خطأ في الخادم' }, { status: 500 })
  }
}
