import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { resolveBusinessId } from '@/lib/db-utils'
import { logAudit } from '@/lib/audit'

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const rawBusinessId = searchParams.get('businessId')
    const status = searchParams.get('status') || ''

    if (!rawBusinessId) {
      return NextResponse.json({ error: 'businessId مطلوب' }, { status: 400 })
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    const where: Record<string, unknown> = { businessId }

    if (status) {
      where.status = status
    }

    const quotes = await db.priceQuote.findMany({
      where,
      include: {
        business: {
          select: { id: true, name: true },
        },
        items: {
          include: {
            product: {
              select: { id: true, name: true, sku: true },
            },
          },
        },
        convertedToInvoice: {
          select: { id: true, invoiceNumber: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json(quotes)
  } catch (error) {
    console.error('Error fetching price quotes:', error)
    return NextResponse.json(
      { error: 'Failed to fetch price quotes' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      businessId: rawBusinessId,
      clientName,
      clientPhone,
      clientId,
      items,
      discountAmount,
      taxAmount,
      validUntil,
      notes,
      status,
    } = body

    if (!rawBusinessId) {
      return NextResponse.json(
        { error: 'businessId is required' },
        { status: 400 }
      )
    }

    const businessId = await resolveBusinessId(rawBusinessId)
    if (!businessId) {
      return NextResponse.json({ error: 'لم يتم العثور على المحل' }, { status: 404 })
    }

    if (!items || items.length === 0) {
      return NextResponse.json(
        { error: 'items are required' },
        { status: 400 }
      )
    }

    // Calculate totals
    const subtotal = items.reduce(
      (sum: number, item: { total?: number; unitPrice?: number; quantity?: number; discountAmount?: number }) => {
        if (item.total) return sum + item.total
        const lineTotal =
          (item.unitPrice || 0) * (item.quantity || 1) - (item.discountAmount || 0)
        return sum + lineTotal
      },
      0
    )

    const totalDiscount = discountAmount ? parseFloat(String(discountAmount)) : 0
    const totalTax = taxAmount ? parseFloat(String(taxAmount)) : 0
    const total = subtotal - totalDiscount + totalTax

    // Generate quote number
    const count = await db.priceQuote.count({
      where: { businessId },
    })
    const quoteNumber = `PQ-${String(count + 1).padStart(5, '0')}`

    // Create the quote with items (NO stock changes)
    const quote = await db.priceQuote.create({
      data: {
        businessId,
        quoteNumber,
        clientId: clientId ? parseInt(String(clientId)) : null,
        clientName,
        clientPhone,
        subtotal,
        discountAmount: totalDiscount,
        taxAmount: totalTax,
        total,
        status: status || 'draft',
        validUntil: validUntil ? new Date(validUntil) : null,
        notes: notes || null,
        issuedAt: new Date(),
        items: {
          create: items.map(
            (item: {
              productId?: number
              description?: string
              quantity?: number
              unitPrice?: number
              discountAmount?: number
              total?: number
            }) => ({
              productId: item.productId ? parseInt(String(item.productId)) : null,
              description: item.description,
              quantity: item.quantity || 1,
              unitPrice: item.unitPrice || 0,
              discountAmount: item.discountAmount || 0,
              total:
                item.total ||
                (item.unitPrice || 0) * (item.quantity || 1) -
                  (item.discountAmount || 0),
            })
          ),
        },
      },
      include: {
        items: {
          include: {
            product: {
              select: { id: true, name: true, sku: true },
            },
          },
        },
      },
    })

    await logAudit({
      businessId,
      action: 'CREATE',
      entity: 'PriceQuote',
      entityId: quote.id,
      changes: { after: { quoteNumber: quote.quoteNumber, total: quote.total, clientName: quote.clientName } },
    })

    return NextResponse.json(quote, { status: 201 })
  } catch (error) {
    console.error('Error creating price quote:', error)
    return NextResponse.json(
      { error: 'Failed to create price quote' },
      { status: 500 }
    )
  }
}
