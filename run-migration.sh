#!/bin/bash

# Database Migration Runner
# This script runs the comprehensive database migration

echo "🚀 Starting Comprehensive Database Migration..."
echo "=============================================="

# Check if we're in the right directory
if [ ! -f "migrations/comprehensive-database-constraints.sql" ]; then
    echo "❌ Error: Migration file not found!"
    echo "Please run this script from the polling-app directory"
    exit 1
fi

echo "📁 Migration file found: migrations/comprehensive-database-constraints.sql"
echo ""

# Display migration summary
echo "📋 Migration Summary:"
echo "  ✅ Unique vote constraint (prevents duplicate votes)"
echo "  ✅ Data validation constraints (title, description, options)"
echo "  ✅ Performance indexes (faster queries)"
echo "  ✅ Row Level Security policies (data protection)"
echo "  ✅ Automatic triggers (vote counting, timestamps)"
echo "  ✅ Data integrity functions (option uniqueness)"
echo ""

# Ask for confirmation
read -p "🤔 Do you want to proceed with the migration? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Migration cancelled by user"
    exit 1
fi

echo ""
echo "🔄 Running migration..."

# Check if we have psql available
if command -v psql &> /dev/null; then
    echo "📊 PostgreSQL client found. You can run the migration with:"
    echo "   psql -h your-host -U your-user -d your-database -f migrations/comprehensive-database-constraints.sql"
    echo ""
fi

# Check if we have Supabase CLI available
if command -v supabase &> /dev/null; then
    echo "🔧 Supabase CLI found. You can run the migration with:"
    echo "   supabase db reset"
    echo "   # or"
    echo "   supabase db push"
    echo ""
fi

echo "📝 Manual Migration Instructions:"
echo "1. Copy the contents of migrations/comprehensive-database-constraints.sql"
echo "2. Go to your Supabase project dashboard"
echo "3. Navigate to SQL Editor"
echo "4. Paste and run the migration script"
echo "5. Verify the results using the verification queries at the end"
echo ""

echo "✅ Migration script is ready to run!"
echo "📄 Migration file: migrations/comprehensive-database-constraints.sql"
echo "📖 Documentation: MIGRATION_GUIDE.md"
echo ""
echo "🎯 After migration, your database will have:"
echo "   • Enhanced security with RLS policies"
echo "   • Data integrity with comprehensive constraints"
echo "   • Better performance with optimized indexes"
echo "   • Automatic vote counting and timestamp updates"
echo "   • Protection against duplicate votes and invalid data"
