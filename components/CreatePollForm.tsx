'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { createPoll } from '@/lib/mock-actions'
import { Plus, X, CheckCircle } from 'lucide-react'

export function CreatePollForm() {
  const router = useRouter()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [options, setOptions] = useState(['', ''])

  const addOption = () => {
    if (options.length < 10) {
      setOptions([...options, ''])
    }
  }

  const removeOption = (index: number) => {
    if (options.length > 2) {
      setOptions(options.filter((_, i) => i !== index))
    }
  }

  const updateOption = (index: number, value: string) => {
    const newOptions = [...options]
    newOptions[index] = value
    setOptions(newOptions)
  }

  const handleSubmit = async (formData: FormData) => {
    setIsSubmitting(true)
    setMessage(null)

    try {
      const result = await createPoll(formData)
      
      if (result.success && result.pollId) {
        setMessage({ type: 'success', text: result.message })
        // Redirect to the created poll after a short delay
        setTimeout(() => {
          router.push(`/polls/${result.pollId}`)
        }, 1500)
      } else {
        setMessage({ type: 'error', text: result.message })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'An unexpected error occurred' })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Poll Details</CardTitle>
        <CardDescription>
          Fill in the details for your new poll
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form action={handleSubmit} className="space-y-6">
          {/* Poll Title */}
          <div className="space-y-2">
            <Label htmlFor="title">Poll Title *</Label>
            <Input
              id="title"
              name="title"
              placeholder="What's your poll about?"
              required
              maxLength={200}
            />
          </div>

          {/* Poll Description */}
          <div className="space-y-2">
            <Label htmlFor="description">Description (Optional)</Label>
            <Textarea
              id="description"
              name="description"
              placeholder="Add more context about your poll..."
              rows={3}
              maxLength={500}
            />
          </div>

          {/* Poll Options */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <Label>Poll Options *</Label>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={addOption}
                disabled={options.length >= 10}
              >
                <Plus className="h-4 w-4 mr-1" />
                Add Option
              </Button>
            </div>
            
            <div className="space-y-3">
              {options.map((option, index) => (
                <div key={index} className="flex items-center gap-2">
                  <Input
                    name="options"
                    placeholder={`Option ${index + 1}`}
                    value={option}
                    onChange={(e) => updateOption(index, e.target.value)}
                    required
                    maxLength={100}
                  />
                  {options.length > 2 && (
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => removeOption(index)}
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  )}
                </div>
              ))}
            </div>
            
            <p className="text-sm text-muted-foreground">
              Minimum 2 options, maximum 10 options
            </p>
          </div>

          {/* Message Display */}
          {message && (
            <div className={`p-4 rounded-md flex items-center gap-2 ${
              message.type === 'success'
                ? 'bg-green-50 text-green-700 border border-green-200'
                : 'bg-red-50 text-red-700 border border-red-200'
            }`}>
              {message.type === 'success' && <CheckCircle className="h-5 w-5" />}
              {message.text}
            </div>
          )}

          {/* Submit Button */}
          <Button
            type="submit"
            disabled={isSubmitting}
            className="w-full"
          >
            {isSubmitting ? 'Creating Poll...' : 'Create Poll'}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}
