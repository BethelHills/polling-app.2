'use client'

import { forwardRef, useState } from 'react'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { AnimatedInput } from '@/components/ui/animated-input'
import { X, GripVertical } from 'lucide-react'

interface OptionInputProps {
  value: string
  onChange: (value: string) => void
  onRemove?: () => void
  placeholder?: string
  error?: string
  success?: boolean
  canRemove?: boolean
  index: number
  className?: string
}

export const OptionInput = forwardRef<HTMLDivElement, OptionInputProps>(
  ({ 
    value, 
    onChange, 
    onRemove, 
    placeholder, 
    error, 
    success, 
    canRemove = false, 
    index,
    className 
  }, ref) => {
    const [isFocused, setIsFocused] = useState(false)
    
    return (
      <div 
        ref={ref}
        className={cn(
          'group flex items-center gap-2 p-1 transition-all duration-200',
          className
        )}
      >
        {/* Drag handle */}
        <div className="opacity-0 group-hover:opacity-100 transition-opacity duration-200">
          <GripVertical className="h-4 w-4 text-muted-foreground cursor-grab" />
        </div>
        
        {/* Option number badge */}
        <div className={cn(
          'flex-shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium transition-colors duration-200',
          isFocused ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'
        )}>
          {index + 1}
        </div>
        
        {/* Input field */}
        <div className="flex-1">
          <AnimatedInput
            value={value}
            onChange={(e) => onChange(e.target.value)}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
            placeholder={placeholder}
            error={error}
            success={success}
            className="transition-all duration-200"
          />
        </div>
        
        {/* Remove button */}
        {canRemove && (
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={onRemove}
            className={cn(
              'opacity-0 group-hover:opacity-100 transition-all duration-200 h-8 w-8 p-0 hover:bg-red-100 hover:text-red-600',
              isFocused && 'opacity-100'
            )}
          >
            <X className="h-4 w-4" />
          </Button>
        )}
      </div>
    )
  }
)

OptionInput.displayName = 'OptionInput'
