'use client'

import { useState, useEffect } from 'react'
import { translations, type Language } from '@/lib/translations'

export function useLanguage() {
  const [language, setLanguage] = useState<Language>('ar')

  useEffect(() => {
    const browserLang = navigator.language.split('-')[0]
    const savedLang = typeof window !== 'undefined' ? localStorage.getItem('preferred_language') as Language : null
    
    if (savedLang && (savedLang === 'ar' || savedLang === 'en')) {
      setLanguage(savedLang)
    } else if (browserLang === 'ar') {
      setLanguage('ar')
    } else {
      setLanguage('en')
    }
  }, [])

  const t = (key: string): string => {
    const keys = key.split('.')
    let value: any = translations[language]
    
    for (const k of keys) {
      if (value === undefined) return key
      value = value[k]
    }
    
    return typeof value === 'string' ? value : key
  }

  const changeLanguage = (lang: Language) => {
    setLanguage(lang)
    if (typeof window !== 'undefined') {
      localStorage.setItem('preferred_language', lang)
      document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr'
      document.documentElement.lang = lang
    }
  }

  const isRTL = language === 'ar'

  return { language, t, changeLanguage, isRTL }
}
