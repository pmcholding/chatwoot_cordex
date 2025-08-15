# Chatwoot Project Overview

## Purpose
Chatwoot is a modern, open-source customer support platform designed as an alternative to Intercom, Zendesk, and Salesforce Service Cloud. It helps businesses deliver exceptional customer support experience with full control over customer data.

## Key Features
- **Omnichannel Support**: Centralizes conversations from multiple channels (live chat, email, Facebook, Instagram, Twitter, WhatsApp, Telegram, Line, SMS)
- **Captain AI Agent**: AI-powered automation for support responses and query handling
- **Help Center Portal**: Built-in knowledge base for self-service support
- **Team Management**: Support for teams, agent assignment, and conversation management
- **Customizable Workflows**: Automation rules, macros, and custom attributes

## Current Conversation Management
- **Status-based system**: open, resolved, pending, snoozed
- **Organization**: By inbox, team, labels, assignee
- **Interface**: List view with filtering and search capabilities
- **No built-in Kanban or phase-based workflow system**

## Architecture
- **Frontend**: Vue.js 3 with Composition API
- **Backend**: Ruby on Rails 7.1
- **Database**: PostgreSQL
- **Styling**: Tailwind CSS only (no custom CSS/scoped styles)
- **Structure**: Modular architecture with clear separation between dashboard, widget, and portal components