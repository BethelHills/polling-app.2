'use client'

import { forwardRef, useState, useEffect } from 'react'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { AnimatedInput, AnimatedTextarea } from '@/components/ui/animated-input'
import { AlertCircle, CheckCircle, Eye, EyeOff, Info } from 'lucide-react'
import { validateField, getCharacterCount } from '@/lib/form-validation'

interface EnhancedFormFieldProps {
  label: string
  value: string
  onChange: (value: string) => void
  type?: 'text' | 'email' | 'password' | 'textarea'
  placeholder?: string
  error?: string
  success?: boolean
  required?: boolean
  maxLength?: number
  showCharacterCount?: boolean
  showValidation?: boolean
  helpText?: string
  className?: string
  allOptions?: string[] // For option validation
  fieldName?: string // For validation
}

export const EnhancedFormField = forwardRef<HTMLDivElement, EnhancedFormFieldProps>(
  ({
    label,
    value,
    onChange,
    type = 'text',
    placeholder,
    error,
    success,
    required = false,
    maxLength = 200,
    showCharacterCount = false,
    showValidation = true,
    helpText,
    className,
    allOptions = [],
    fieldName = 'title'
  }, ref) => {
    const [isFocused, setIsFocused] = useState(false)
    const [showPassword, setShowPassword] = useState(false)
    const [validationError, setValidationError] = useState<string | null>(null)
    const [hasInteracted, setHasInteracted] = useState(false)
    
    // Real-time validation
    useEffect(() => {
      if (hasInteracted && showValidation) {
        const error = validateField(fieldName, value, allOptions)
        setValidationError(error)
      }
    }, [value, allOptions, hasInteracted, showValidation, fieldName])
    
    const handleFocus = () => {
      setIsFocused(true)
      setHasInteracted(true)
    }
    
    const handleBlur = () => {
      setIsFocused(false)
    }
    
    const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
      const newValue = e.target.value
      if (newValue.length <= maxLength) {
        onChange(newValue)
      }
    }
    
    const currentError = error || validationError
    const isSuccess = success && !currentError && value.trim().length > 0
    const characterCount = getCharacterCount(value, maxLength)
    const isNearLimit = characterCount.current > maxLength * 0.8
    
    const inputProps = {
      value,
      onChange: handleChange,
      onFocus: handleFocus,
      onBlur: handleBlur,
      placeholder,
      error: currentError || undefined,
      success: isSuccess,
      maxLength,
      'aria-describedby': [
        currentError ? `${fieldName}-error` : undefined,
        helpText ? `${fieldName}-help` : undefined,
        showCharacterCount ? `${fieldName}-count` : undefined
      ].filter(Boolean).join(' ') || undefined
    }
    
    return (
      <div ref={ref} className={cn('space-y-2', className)}>
        {/* Label */}
        <label 
          htmlFor={fieldName}
          className={cn(
            'text-sm font-medium transition-colors duration-200',
            currentError ? 'text-red-600' : 
            isSuccess ? 'text-green-600' :
            isFocused ? 'text-primary' : 'text-foreground'
          )}
        >
          {label}
          {required && <span className="text-red-500 ml-1">*</span>}
        </label>
        
        {/* Input Container */}
        <div className="relative">
          {type === 'textarea' ? (
            <AnimatedTextarea
              id={fieldName}
              {...inputProps}
              className={cn(
                'min-h-[100px] resize-none',
                currentError && 'border-red-300 focus-visible:ring-red-200',
                isSuccess && 'border-green-300 focus-visible:ring-green-200'
              )}
            />
          ) : (
            <div className="relative">
              <AnimatedInput
                id={fieldName}
                type={type === 'password' && showPassword ? 'text' : type}
                {...inputProps}
                className={cn(
                  type === 'password' && 'pr-10',
                  currentError && 'border-red-300 focus-visible:ring-red-200',
                  isSuccess && 'border-green-300 focus-visible:ring-green-200'
                )}
              />
              
              {/* Password toggle */}
              {type === 'password' && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="absolute right-2 top-1/2 transform -translate-y-1/2 h-6 w-6 p-0 hover:bg-transparent"
                  onClick={() => setShowPassword(!showPassword)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? (
                    <EyeOff className="h-4 w-4 text-muted-foreground" />
                  ) : (
                    <Eye className="h-4 w-4 text-muted-foreground" />
                  )}
                </Button>
              )}
            </div>
          )}
          
          {/* Validation status indicator */}
          {showValidation && (
            <div className="absolute right-3 top-1/2 transform -translate-y-1/2">
              {currentError && <AlertCircle className="h-4 w-4 text-red-500 animate-pulse" />}
              {isSuccess && !currentError && <CheckCircle className="h-4 w-4 text-green-500 animate-in zoom-in-50 duration-200" />}
            </div>
          )}
        </div>
        
        {/* Help text */}
        {helpText && (
          <p 
            id={`${fieldName}-help`}
            className="text-xs text-muted-foreground flex items-center gap-1"
          >
            <Info className="h-3 w-3 flex-shrink-0" />
            {helpText}
          </p>
        )}
        
        {/* Character count */}
        {showCharacterCount && (
          <div 
            id={`${fieldName}-count`}
            className={cn(
              'text-xs transition-colors duration-200',
              characterCount.isOverLimit ? 'text-red-600' :
              isNearLimit ? 'text-orange-600' : 'text-muted-foreground'
            )}
          >
            {characterCount.current}/{characterCount.max}
            {characterCount.isOverLimit && ' (over limit)'}
          </div>
        )}
        
        {/* Error message */}
        {currentError && (
          <div 
            id={`${fieldName}-error`}
            className="flex items-center gap-1 text-xs text-red-600 animate-in slide-in-from-top-1 duration-200"
            role="alert"
          >
            <AlertCircle className="h-3 w-3 flex-shrink-0" />
            <span>{currentError}</span>
          </div>
        )}
        
        {/* Success message */}
        {isSuccess && !currentError && (
          <div className="flex items-center gap-1 text-xs text-green-600 animate-in slide-in-from-top-1 duration-200">
            <CheckCircle className="h-3 w-3 flex-shrink-0" />
            <span>Looks good!</span>
          </div>
        )}
      </div>
    )
  }
)

EnhancedFormField.displayName = 'EnhancedFormField'
