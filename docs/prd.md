# Chatwoot Kanban Enhancement PRD

## Intro Project Analysis and Context

### Existing Project Overview

**Analysis Source**: IDE-based fresh analysis of Chatwoot codebase

**Current Project State**: Chatwoot é uma plataforma de atendimento ao cliente open-source com as seguintes características principais:

- **Backend**: Ruby on Rails 7.1 com PostgreSQL
- **Frontend**: Vue.js 3 com Composition API
- **Arquitetura**: Modular com separação clara entre dashboard, widget e portal
- **Sistema de Conversas**: Baseado em status (open, resolved, pending, snoozed)
- **Estrutura Principal**:
  - `/app/models/conversation.rb`: Modelo principal das conversas
  - `/app/javascript/dashboard/`: Interface do dashboard em Vue.js
  - Sistema de inboxes para organizar conversas por canal
  - Sistema de labels para categorização
  - Sistema de teams para organização de agentes

### Available Documentation Analysis

**Available Documentation**:
- ✓ Tech Stack Documentation (Ruby 3.4.4, Rails 7.1, Vue.js 3)
- ✓ Source Tree/Architecture (MVC Rails + Vue.js modular)
- ✓ Coding Standards (RuboCop + ESLint com Airbnb config)
- ✓ API Documentation (RESTful JSON APIs)
- ✓ External API Documentation (ActionCable WebSockets)
- ✓ Technical Debt Documentation (Tailwind-only styling, deprecating old components)

### Enhancement Scope Definition

**Enhancement Type**:
- ✓ New Feature Addition
- ✓ Major Feature Modification (conversation management)
- ✓ UI/UX Overhaul (new Kanban visualization)

**Enhancement Description**: Criação de uma nova seção no menu que seria o kanban onde o usuário vê as conversas por etapas e consegue mover os cards usando drag and drop mudando de fase e organizando as conversas manualmente. O usuário poderá criar fases, mudar cor, reordenar fases e usar filtros, incluindo uma seção na conversa para alterar a fase diretamente.

**Impact Assessment**:
- ✓ Significant Impact (substantial existing code changes)
- Database schema changes required
- New UI components and routing
- API extensions needed

### Goals and Background Context

**Goals**:
• Permitir visualização visual das conversas em formato Kanban por fases customizáveis
• Capacitar usuários a organizar conversas manualmente via drag & drop
• Fornecer gestão completa de fases (criar, editar, reordenar, colorir)
• Integrar filtros avançados para otimizar workflow de atendimento
• Possibilitar mudança de fase diretamente na tela de conversa

**Background Context**: O sistema atual do Chatwoot organiza conversas por status pré-definidos (open, resolved, pending, snoozed) em formato de lista. Embora funcional, esta abordagem não oferece flexibilidade para workflows customizados nem visualização intuitiva do fluxo de trabalho. Equipes de suporte precisam de maior controle sobre a organização de conversas e visualização do pipeline de atendimento, similar ao que ferramentas como Trello ou Jira oferecem para gestão de projetos.

**Change Log**:
| Change | Date | Version | Description | Author |
|--------|------|---------|-------------|---------|
| Initial PRD | 2025-01-15 | 1.0 | Criação do PRD para sistema Kanban | Product Team |

## Requirements

### Functional

**FR1**: O sistema deve criar uma nova seção "Kanban" no menu principal do dashboard, posicionada entre "Conversations" e "Contacts"

**FR2**: O Kanban deve exibir conversas como cards organizados em colunas que representam fases customizáveis pelo usuário

**FR3**: Usuários devem poder arrastar e soltar cards entre fases usando drag & drop, atualizando automaticamente o campo de fase da conversa

**FR4**: O sistema deve permitir criar, editar, reordenar e excluir fases customizáveis com nome e cor personalizável

**FR5**: Cada card deve exibir informações essenciais: título da conversa, contact name, assignee, labels, último update, e indicador de urgência

**FR6**: O sistema deve incluir filtros avançados: inbox, assignee, labels, created date range, priority, e search por contact/conversation

**FR7**: Na tela individual da conversa, deve haver uma seção para alterar a fase atual sem sair da conversa

**FR8**: O sistema deve preservar todas as funcionalidades existentes de status (open/resolved/pending/snoozed) paralelamente ao sistema de fases

### Non Functional

**NFR1**: O sistema deve carregar o Kanban com até 500 conversas em menos de 2 segundos

**NFR2**: Operações de drag & drop devem ter resposta imediata (<200ms) com fallback em caso de erro de rede

**NFR3**: O sistema deve ser responsivo e funcional em desktop, tablet e mobile

**NFR4**: Deve suportar até 20 fases customizáveis por account sem degradação de performance

**NFR5**: A interface deve seguir o design system existente do Chatwoot mantendo consistência visual

### Compatibility Requirements

**CR1**: O novo sistema de fases deve coexistir com o sistema atual de status de conversas sem conflitos

**CR2**: Todas as APIs existentes de conversas devem continuar funcionando sem alterações para manter compatibilidade com integrações

**CR3**: O sistema deve manter compatibilidade com filtros, busca e labels existentes

**CR4**: Permissões de acesso devem usar o sistema atual de roles e policies do Chatwoot

## User Interface Enhancement Goals

### Integration with Existing UI

O novo sistema Kanban seguirá o design system atual do Chatwoot:
- **Components**: Utilizará `components-next/` para todos os novos componentes
- **Styling**: Exclusivamente Tailwind CSS seguindo `tailwind.config.js`
- **Layout**: Integrará ao layout principal do dashboard mantendo sidebar e header existentes
- **Consistência**: Cards, botões, dropdowns e modals seguirão os padrões visuais estabelecidos
- **Responsividade**: Mobile-first approach seguindo breakpoints do Tailwind

### Modified/New Screens and Views

**Telas que serão criadas:**
1. `/dashboard/kanban` - Tela principal do Kanban
2. `/dashboard/kanban/settings` - Configuração de fases
3. Componente de seleção de fase dentro da tela de conversa existente

**Telas que serão modificadas:**
1. Sidebar principal - adição do item "Kanban" 
2. Tela de conversa individual - seção para mudança de fase

### UI Consistency Requirements

- Manter paleta de cores existente para indicadores de status e prioridade
- Usar sistema de ícones atual (Heroicons/Tabler icons)
- Seguir tipografia e spacing definidos no design system
- Cards do Kanban devem ter aparência similar aos cards de conversas existentes
- Animações de drag & drop devem ser sutis e consistentes com micro-interações atuais

## Technical Constraints and Integration Requirements

### Existing Technology Stack

**Languages**: Ruby 3.4.4, JavaScript ES6+, TypeScript (Vite)
**Frameworks**: Rails 7.1, Vue.js 3 with Composition API
**Database**: PostgreSQL com indexes otimizados
**Infrastructure**: Redis para cache, Sidekiq para background jobs, ActionCable para WebSockets
**External Dependencies**: Tailwind CSS, Vuex, Vue Router, Vitest

### Integration Approach

**Database Integration Strategy**: Adicionar campo `kanban_stage_id` na tabela `conversations` com foreign key para nova tabela `kanban_stages`. Manter índices existentes e adicionar índice composto `(account_id, kanban_stage_id)` para performance.

**API Integration Strategy**: Estender controller `Api::V1::ConversationsController` com endpoint PATCH `/conversations/:id/kanban_stage`. Criar novo controller `Api::V1::KanbanStagesController` para CRUD de fases. Usar serializers existentes.

**Frontend Integration Strategy**: Criar nova rota `/dashboard/kanban` no Vue Router. Implementar store module `kanban.js` no Vuex. Usar composables existentes (`useAccount`, `usePolicy`) para consistência.

**Testing Integration Strategy**: Seguir padrões existentes com RSpec para backend, Vitest para frontend. Usar factories existentes e criar `kanban_stages.rb` factory.

### Code Organization and Standards

**File Structure Approach**: 
```
app/models/kanban_stage.rb
app/controllers/api/v1/kanban_stages_controller.rb
app/javascript/dashboard/api/kanbanStages.js
app/javascript/dashboard/store/modules/kanban.js
app/javascript/dashboard/routes/dashboard/kanban/
```

**Naming Conventions**: KanbanStage (model), kanban-stages (API), kanbanStages (JS), KanbanBoard (Vue component)

**Coding Standards**: RuboCop para Ruby, ESLint + Airbnb config para JS/Vue, PropTypes para componentes Vue

**Documentation Standards**: JSDoc para funções complexas, comentários inline para lógica de drag & drop

### Deployment and Operations

**Build Process Integration**: Nenhuma alteração necessária no Vite/Rails asset pipeline

**Deployment Strategy**: Deploy incremental com feature flag `kanban_enabled` para rollout controlado

**Monitoring and Logging**: Usar Rails logger existente para ações de Kanban, métricas de performance via existing telemetry

**Configuration Management**: Usar Rails credentials para configurações, limites via `Rails.application.config`

### Risk Assessment and Mitigation

**Technical Risks**: Performance com muitas conversas, conflitos de drag & drop simultâneo, complexidade de state management

**Integration Risks**: Breaking changes em APIs existentes, conflitos com filtros atuais, problemas de permissões

**Deployment Risks**: Downtime durante migrations, rollback complexity com nova tabela

**Mitigation Strategies**: Feature toggles, database migrations incrementais, extensive testing, gradual rollout por accounts

## Epic and Story Structure

### Epic Approach

**Epic Structure Decision**: Single epic for brownfield with rationale - Esta é uma funcionalidade coesa que adiciona visualização Kanban ao sistema existente de conversas. Todas as user stories são interdependentes e precisam ser entregues de forma sequencial para criar uma experiência completa. Separar em múltiplos epics fragmentaria a funcionalidade e criaria dependências complexas entre entregas.

## Epic 1: Sistema Kanban para Gestão de Conversas

**Epic Goal**: Implementar visualização Kanban completa que permite organizar conversas em fases customizáveis com drag & drop, mantendo total compatibilidade com funcionalidades existentes do Chatwoot.

**Integration Requirements**: Integração total com sistema de permissões, filtros, busca, labels e status existentes. Coexistência com workflows atuais sem breaking changes.

### Story 1.1: Estrutura de Dados para Fases Kanban

Como um **desenvolvedor**,
Eu quero **criar a estrutura de dados para fases Kanban**,
Para que **o sistema possa armazenar e gerenciar fases customizáveis por account**.

**Acceptance Criteria:**
1. Tabela `kanban_stages` criada com campos: id, account_id, name, color, position, created_at, updated_at
2. Modelo `KanbanStage` com validações: presence de name/color, uniqueness de name per account, position sequence
3. Relacionamento Account has_many :kanban_stages estabelecido
4. Índices de performance criados: (account_id), (account_id, position)
5. Migration inclui rollback seguro e dados seed para accounts existentes

**Integration Verification:**
- **IV1**: Todas as queries existentes de Account continuam funcionando sem impacto de performance
- **IV2**: Sistema de permissões existente funciona corretamente com novo modelo
- **IV3**: Rollback da migration não causa perda de dados ou downtime

### Story 1.2: API para Gerenciamento de Fases

Como um **administrador de account**,
Eu quero **gerenciar fases Kanban via API**,
Para que **possa criar, editar, reordenar e excluir fases customizadas**.

**Acceptance Criteria:**
1. Controller `Api::V1::KanbanStagesController` implementado com CRUD completo
2. Endpoints: GET /api/v1/accounts/:id/kanban_stages, POST, PATCH, DELETE /api/v1/accounts/:id/kanban_stages/:stage_id
3. Serializer `KanbanStageSerializer` retorna: id, name, color, position, conversations_count
4. Validação de permissions usando policies existentes
5. Testes de controller cobrindo todos cenários e edge cases

**Integration Verification:**
- **IV1**: APIs existentes de Account e Conversations não são afetadas
- **IV2**: Sistema de autenticação e autorização funciona corretamente
- **IV3**: Rate limiting e throttling aplicados consistentemente

### Story 1.3: Adição de Campo Stage às Conversas

Como um **usuário do sistema**,
Eu quero **que conversas possam ter fases atribuídas**,
Para que **cada conversa possa ser categorizada em uma fase específica**.

**Acceptance Criteria:**
1. Campo `kanban_stage_id` adicionado à tabela conversations com foreign key constraint
2. Relacionamento Conversation belongs_to :kanban_stage, optional: true estabelecido  
3. Endpoint PATCH /api/v1/conversations/:id/kanban_stage implementado
4. Validação que stage pertence ao mesmo account da conversa
5. Serializer de Conversation inclui kanban_stage quando presente

**Integration Verification:**
- **IV1**: Todas as queries existentes de Conversation mantêm performance
- **IV2**: Filtros e buscas existentes continuam funcionando normalmente
- **IV3**: Webhooks e integrações externas recebem campo adicional sem quebrar

### Story 1.4: Interface de Configuração de Fases

Como um **administrador**,
Eu quero **uma interface para gerenciar minhas fases Kanban**,
Para que **possa criar, editar, reordenar e personalizar fases com cores**.

**Acceptance Criteria:**
1. Rota `/dashboard/kanban/settings` criada no Vue Router
2. Componente `KanbanStageSettings.vue` implementado com lista drag-and-drop
3. Modal para criar/editar fases com campos: name, color picker, position
4. Validação frontend: nome obrigatório, cor válida, máximo 20 fases
5. Toast notifications para sucesso/erro em operações

**Integration Verification:**
- **IV1**: Sidebar navigation mantém estados e highlights corretos
- **IV2**: Sistema de permissões frontend funciona corretamente
- **IV3**: Breadcrumbs e navigation paths atualizados adequadamente

### Story 1.5: Visualização Kanban Principal

Como um **agente de suporte**,
Eu quero **visualizar conversas em formato Kanban**,
Para que **possa ver o status visual de todas as conversas organizadas por fases**.

**Acceptance Criteria:**
1. Rota `/dashboard/kanban` implementada com componente `KanbanBoard.vue`
2. Colunas representam fases, cards representam conversas
3. Cards mostram: contact name, subject, assignee avatar, labels, last activity
4. Loading states e empty states para fases sem conversas
5. Responsivo para desktop, tablet e mobile

**Integration Verification:**
- **IV1**: Performance mantida com até 500 conversas carregadas
- **IV2**: Sistema de real-time updates via ActionCable funciona
- **IV3**: Filtros globais de inbox/team aplicados corretamente

### Story 1.6: Drag and Drop entre Fases

Como um **agente**,
Eu quero **arrastar conversas entre fases**,
Para que **possa organizar e atualizar o status das conversas visualmente**.

**Acceptance Criteria:**
1. Drag & drop implementado com feedback visual durante arrasto
2. API call automático ao soltar conversa em nova fase
3. Rollback visual em caso de erro na API
4. Confirmação visual de sucesso após mudança
5. Prevenção de drops inválidos com indicadores visuais

**Integration Verification:**
- **IV1**: Operações simultâneas de múltiplos usuários tratadas adequadamente
- **IV2**: Permissões de edição de conversa respeitadas no drag & drop
- **IV3**: Webhooks e automation rules existentes disparados corretamente

### Story 1.7: Filtros Avançados no Kanban

Como um **usuário**,
Eu quero **filtrar conversas no Kanban**,
Para que **possa focar em subconjuntos específicos de conversas**.

**Acceptance Criteria:**
1. Barra de filtros com: inbox, assignee, labels, date range, priority, search
2. Aplicação de filtros atualiza todas as colunas simultaneamente
3. Indicadores visuais de filtros ativos
4. Persistência de filtros na sessão do usuário
5. Reset rápido de todos os filtros

**Integration Verification:**
- **IV1**: Filtros usam mesma lógica das telas existentes de conversa
- **IV2**: Performance mantida mesmo com filtros complexos
- **IV3**: URLs refletem estado dos filtros para compartilhamento

### Story 1.8: Seletor de Fase na Conversa

Como um **agente**,
Eu quero **alterar a fase da conversa sem sair dela**,
Para que **possa atualizar o status rapidamente durante o atendimento**.

**Acceptance Criteria:**
1. Dropdown de seleção de fase adicionado ao sidebar da conversa
2. Lista todas as fases disponíveis com cores identificadoras
3. Mudança reflete instantaneamente com loading indicator
4. Integração com atalhos de teclado existentes
5. Log de mudança de fase no histórico da conversa

**Integration Verification:**
- **IV1**: Sidebar existente mantém layout e funcionalidades
- **IV2**: Mudanças refletem no Kanban se estiver aberto simultaneamente
- **IV3**: Automation rules e triggers continuam funcionando

---

**Generated with [Claude Code](https://claude.ai/code)**

**Co-Authored-By: Claude <noreply@anthropic.com>**