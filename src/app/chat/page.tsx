'use client'

import { useState, useEffect, useRef, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

interface Chat {
  id: string
  participant1?: { id: string; name: string }
  participant2?: { id: string; name: string }
  otherUser?: { id: string; name: string }
  lastMessage?: string
  updatedAt?: string
}

interface Message {
  id: string
  content: string
  senderId: string
  createdAt: string
}

function ChatPageInner() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [user, setUser] = useState<any>(null)
  const [chats, setChats] = useState<Chat[]>([])
  const [selectedChat, setSelectedChat] = useState<string | null>(null)
  const [messages, setMessages] = useState<Message[]>([])
  const [newMsg, setNewMsg] = useState('')
  const [loadingChats, setLoadingChats] = useState(true)
  const [loadingMessages, setLoadingMessages] = useState(false)

  const [showChatList, setShowChatList] = useState(true)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const stored = localStorage.getItem('sana3i_user')
    if (stored) {
      const parsed = JSON.parse(stored)
      setUser(parsed)
      loadChats(parsed.id)
      const conversationId = searchParams.get('conversationId')
      if (conversationId) {
        loadMessages(conversationId)
      }
    } else {
      router.push('/login')
    }
  }, [router])

  const loadChats = async (uid: string) => {
    try {
      const res = await fetch('/api/chats', { credentials: 'include' })
      const data = await res.json()
      const raw = data.chats || data.data || []
      // تنسيق البيانات لعرض اسم الطرف الآخر
      const formatted = raw.map((c: any) => {
        const other = c.participant1?.id === uid ? c.participant2 : c.participant1
        return { ...c, otherUser: other }
      })
      setChats(formatted)
    } catch (e) {
      console.error('Failed to load chats', e)
    } finally {
      setLoadingChats(false)
    }
  }

  const loadMessages = async (chatId: string) => {
    setLoadingMessages(true)
    setSelectedChat(chatId)
    setShowChatList(false)
    try {
      const res = await fetch(`/api/chats/${chatId}/messages`, { credentials: 'include' })
      const data = await res.json()
      setMessages(data.messages || data.data || [])
    } catch (e) {
      console.error('Failed to load messages', e)
    } finally {
      setLoadingMessages(false)
      setTimeout(() => messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 100)
    }
  }

  const sendMessage = async () => {
    if (!newMsg.trim() || !selectedChat || !user) return
    try {
      const res = await fetch(`/api/chats/${selectedChat}/messages`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: newMsg }),
      })
      if (res.ok) {
        const data = await res.json()
        setMessages(prev => [...prev, data.message || data])
        setNewMsg('')
        setTimeout(() => messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 100)
      }
    } catch (e) {
      console.error('Failed to send message', e)
    }
  }

  if (!user) return <div className="p-8 text-center">تحميل...</div>

  return (
    <div dir="rtl" className="min-h-screen bg-gray-50 flex">
      {/* الشريط الجانبي للمحادثات */}
      <div className={`w-full md:w-80 bg-white border-l overflow-y-auto ${showChatList ? "block" : "hidden md:block"}`}>
        <div className="p-4 border-b">
          <h2 className="text-xl font-bold">المحادثات</h2>
        </div>
        {loadingChats ? (
          <p className="p-4 text-gray-700">تحميل...</p>
        ) : chats.length === 0 ? (
          <p className="p-4 text-gray-700">لا توجد محادثات بعد</p>
        ) : (
          chats.map(chat => (
            <div
              key={chat.id}
              onClick={() => loadMessages(chat.id)}
              className={`p-4 border-b cursor-pointer hover:bg-gray-50 ${selectedChat === chat.id ? 'bg-blue-50' : ''}`}
            >
              <div className="font-semibold">{chat.otherUser?.name || 'محادثة'}</div>
              {chat.lastMessage && <div className="text-sm text-gray-700 truncate">{chat.lastMessage}</div>}
            </div>
          ))
        )}
      </div>

      {/* نافذة المحادثة */}
      <div className="flex-1 flex flex-col">
        {selectedChat ? (
          <>
            <div className="bg-white border-b p-4 font-bold flex items-center gap-2">
              <button
                onClick={() => setShowChatList(true)}
                className="md:hidden flex items-center gap-1 text-blue-600 bg-blue-50 hover:bg-blue-100 transition rounded-lg px-3 py-1.5 text-sm shrink-0"
              >
                <span className="text-lg leading-none">→</span>
                <span>رجوع</span>
              </button>
              <span className="truncate">{chats.find(c => c.id === selectedChat)?.otherUser?.name || 'محادثة'}</span>
            </div>
            <div className="flex-1 overflow-y-auto p-4 space-y-3">
              {loadingMessages ? (
                <p className="text-center text-gray-700">تحميل الرسائل...</p>
              ) : messages.length === 0 ? (
                <p className="text-center text-gray-700">لا توجد رسائل. ابدأ المحادثة!</p>
              ) : (
                messages.map(msg => (
                  <div key={msg.id} className={`flex ${msg.senderId === user.id ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-xs px-4 py-2 rounded-xl ${msg.senderId === user.id ? 'bg-blue-600 text-white' : 'bg-gray-200 text-gray-800'}`}>
                      <p className="text-sm">{msg.content}</p>
                      <span className="text-xs opacity-70">{new Date(msg.createdAt).toLocaleTimeString('ar', { hour: '2-digit', minute: '2-digit' })}</span>
                    </div>
                  </div>
                ))
              )}
              <div ref={messagesEndRef} />
            </div>
            <div className="bg-white border-t p-3 flex gap-2">
              <input
                type="text"
                value={newMsg}
                onChange={(e) => setNewMsg(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
                placeholder="اكتب رسالتك..."
                className="flex-1 border border-gray-300 rounded-lg px-3 py-2"
              />
              <button
                onClick={sendMessage}
                className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition"
              >
                إرسال
              </button>
            </div>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center text-gray-700">
            اختر محادثة من القائمة
          </div>
        )}
      </div>

      {/* زر العودة للرئيسية */}
      {!selectedChat && (
        <div className="fixed bottom-4 right-4 md:hidden">
          <button
            onClick={() => router.push('/')}
            className="bg-white shadow-lg rounded-full p-3"
          >
            🏠
          </button>
        </div>
      )}
    </div>
  )
}

export default function ChatPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center">تحميل...</div>}>
      <ChatPageInner />
    </Suspense>
  )
}
