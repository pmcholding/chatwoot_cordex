# Chatwoot Technology Stack

## Backend
- **Framework**: Ruby on Rails 7.1
- **Ruby Version**: 3.4.4
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq
- **Redis**: For caching and ActionCable
- **API**: RESTful JSON APIs

## Frontend
- **Framework**: Vue.js 3 with Composition API
- **Build Tool**: Vite
- **State Management**: Vuex
- **Styling**: Tailwind CSS (exclusively)
- **Testing**: Vitest
- **Module System**: ES6 modules

## Development Tools
- **Process Manager**: Overmind (for development)
- **Package Manager**: 
  - Ruby: Bundler
  - JavaScript: pnpm
- **Linting**: 
  - Ruby: RuboCop
  - JavaScript/Vue: ESLint (Airbnb base + Vue 3 recommended)
- **Testing**:
  - Ruby: RSpec
  - JavaScript: Vitest

## Key Dependencies
- **Rails Gems**: acts-as-taggable-on, kaminari, responders, jbuilder
- **Frontend**: Vue Router, ActionCable integration
- **UI Framework**: Custom component system with Tailwind

## Architecture Patterns
- **MVC**: Standard Rails MVC pattern
- **Component-based**: Vue.js component architecture
- **API-first**: Separation between backend API and frontend
- **Real-time**: ActionCable for WebSocket communication