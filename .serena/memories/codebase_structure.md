# Chatwoot Codebase Structure

## Root Directory Structure
```
/
├── app/                    # Rails application code
├── config/                 # Configuration files
├── db/                     # Database migrations and schema
├── lib/                    # Custom libraries and utilities
├── spec/                   # Ruby test files
├── public/                 # Static assets
├── docs/                   # Project documentation
└── enterprise/             # Enterprise features
```

## Backend Structure (`app/`)
```
app/
├── models/                 # ActiveRecord models
│   ├── conversation.rb     # Core conversation model
│   ├── account.rb         # Account/organization model
│   ├── user.rb            # User model
│   └── ...
├── controllers/           # Rails controllers
│   └── api/              # API endpoints
├── services/             # Business logic services
├── jobs/                 # Background jobs
├── policies/             # Authorization policies
├── mailers/              # Email handling
└── views/                # Rails views (minimal, mostly API)
```

## Frontend Structure (`app/javascript/`)
```
app/javascript/
├── dashboard/            # Main dashboard application
│   ├── api/             # API client modules
│   ├── components/      # Vue components (legacy)
│   ├── components-next/ # New Vue components (preferred)
│   ├── routes/          # Vue Router configuration
│   ├── store/           # Vuex store modules
│   ├── composables/     # Vue composables
│   └── assets/          # Dashboard-specific assets
├── widget/              # Customer-facing chat widget
├── portal/              # Help center portal
└── shared/              # Shared components and utilities
```

## Key Model Relationships
- **Account** → has many Users, Conversations, Inboxes
- **Conversation** → belongs to Account, Inbox, Contact; has many Messages
- **User** → belongs to Account; can be assigned to Conversations
- **Inbox** → belongs to Account; has many Conversations
- **Message** → belongs to Conversation, Account

## Configuration Files
- `config/routes.rb` - Rails routing
- `tailwind.config.js` - Tailwind CSS configuration
- `vite.config.ts` - Vite build configuration
- `Procfile.dev` - Development process configuration