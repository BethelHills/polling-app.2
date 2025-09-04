import { NextRequest, NextResponse } from 'next/server'
import { supabaseAdmin } from '@/lib/supabase'
import { z } from 'zod'

// Validation schema for poll creation
const createPollSchema = z.object({
  title: z.string().min(3, 'Title must be at least 3 characters').max(200, 'Title must be less than 200 characters'),
  description: z.string().max(500, 'Description must be less than 500 characters').optional(),
  options: z.array(z.string().min(1, 'Option text is required').max(100, 'Option must be less than 100 characters'))
    .min(2, 'At least 2 options are required')
    .max(10, 'Maximum 10 options allowed')
    .refine(
      (options) => {
        const texts = options.map(opt => opt.trim().toLowerCase())
        return new Set(texts).size === texts.length
      },
      { message: 'Options must be unique' }
    )
})

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    
    // Validate the request body
    const validationResult = createPollSchema.safeParse(body)
    
    if (!validationResult.success) {
      return NextResponse.json(
        { 
          success: false, 
          message: 'Validation failed',
          errors: validationResult.error?.issues?.map(err => ({
            field: err.path.join('.'),
            message: err.message
          })) || []
        },
        { status: 400 }
      )
    }

    const { title, description, options } = validationResult.data

    // Create the poll
    const { data: poll, error: pollError } = await supabaseAdmin
      .from('polls')
      .insert({
        title,
        description: description || null,
        is_active: true
      })
      .select()
      .single()

    if (pollError) {
      console.error('Error creating poll:', pollError)
      return NextResponse.json(
        { success: false, message: 'Failed to create poll' },
        { status: 500 }
      )
    }

    // Create the poll options
    const optionsData = options
      .filter(option => option.trim())
      .map((option, index) => ({
        poll_id: poll.id,
        text: option.trim(),
        votes: 0,
        order: index
      }))

    const { error: optionsError } = await supabaseAdmin
      .from('poll_options')
      .insert(optionsData)

    if (optionsError) {
      console.error('Error creating poll options:', optionsError)
      return NextResponse.json(
        { success: false, message: 'Poll created but options failed' },
        { status: 500 }
      )
    }

    return NextResponse.json(
      { 
        success: true, 
        message: 'Poll created successfully!', 
        pollId: poll.id,
        poll: {
          id: poll.id,
          title: poll.title,
          description: poll.description,
          options: optionsData
        }
      },
      { status: 201 }
    )

  } catch (error) {
    console.error('Error in poll creation API:', error)
    return NextResponse.json(
      { success: false, message: 'An unexpected error occurred' },
      { status: 500 }
    )
  }
}

export async function GET() {
  try {
    const { data: polls, error } = await supabaseAdmin
      .from('polls')
      .select(`
        *,
        options: poll_options (
          id,
          votes
        )
      `)
      .eq('is_active', true)
      .order('created_at', { ascending: false })

    if (error) {
      console.error('Error fetching polls:', error)
      return NextResponse.json(
        { success: false, message: 'Failed to fetch polls' },
        { status: 500 }
      )
    }

    // Calculate total votes for each poll
    const pollsWithVotes = polls.map(poll => ({
      ...poll,
      total_votes: poll.options.reduce((sum: number, option: any) => sum + option.votes, 0)
    }))

    return NextResponse.json(
      { 
        success: true, 
        polls: pollsWithVotes 
      },
      { status: 200 }
    )

  } catch (error) {
    console.error('Error in polls GET API:', error)
    return NextResponse.json(
      { success: false, message: 'An unexpected error occurred' },
      { status: 500 }
    )
  }
}
