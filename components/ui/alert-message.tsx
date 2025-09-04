'use client'

import { forwardRef } from 'react'
import { cn } from '@/lib/utils'
import { CheckCircle, AlertCircle, X, Info } from 'lucide-react'
import { Button } from '@/components/ui/button'

interface AlertMessageProps {
  type: 'success' | 'error' | 'warning' | 'info'
  title?: string
  message: string
  onDismiss?: () => void
  className?: string
  showIcon?: boolean
}

export const AlertMessage = forwardRef<HTMLDivElement, AlertMessageProps>(
  ({ type, title, message, onDismiss, className, showIcon = true }, ref) => {
    const getIcon = () => {
      switch (type) {
        case 'success':
          return <CheckCircle className="h-5 w-5" />
        case 'error':
          return <AlertCircle className="h-5 w-5" />
        case 'warning':
          return <AlertCircle className="h-5 w-5" />
        case 'info':
          return <Info className="h-5 w-5" />
        default:
          return null
      }
    }

    const getStyles = () => {
      switch (type) {
        case 'success':
          return 'bg-green-50 text-green-800 border-green-200'
        case 'error':
          return 'bg-red-50 text-red-800 border-red-200'
        case 'warning':
          return 'bg-yellow-50 text-yellow-800 border-yellow-200'
        case 'info':
          return 'bg-blue-50 text-blue-800 border-blue-200'
        default:
          return 'bg-gray-50 text-gray-800 border-gray-200'
      }
    }

    return (
      <div
        ref={ref}
        className={cn(
          'relative p-4 rounded-lg border transition-all duration-300 animate-in slide-in-from-top-2',
          getStyles(),
          className
        )}
      >
        <div className="flex items-start gap-3">
          {showIcon && (
            <div className="flex-shrink-0 mt-0.5">
              {getIcon()}
            </div>
          )}
          
          <div className="flex-1 min-w-0">
            {title && (
              <h4 className="font-semibold mb-1">
                {title}
              </h4>
            )}
            <p className="text-sm">
              {message}
            </p>
          </div>
          
          {onDismiss && (
            <Button
              variant="ghost"
              size="sm"
              onClick={onDismiss}
              className="flex-shrink-0 h-6 w-6 p-0 hover:bg-black/10"
            >
              <X className="h-4 w-4" />
            </Button>
          )}
        </div>
      </div>
    )
  }
)

AlertMessage.displayName = 'AlertMessage'
