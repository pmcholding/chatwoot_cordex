### **Documento de Arquitetura Brownfield: Fluxo de Criação de Assistente de IA**

**1. Introdução**

Este documento captura o estado atual das áreas relevantes do projeto `chatwoot_cordex` e descreve a arquitetura para a implementação da funcionalidade "Fluxo de Criação de Assistente de IA", conforme definido no PRD. O objetivo é guiar os desenvolvedores (IA e humanos) na integração do novo recurso de forma consistente com os padrões existentes.

**2. Análise de Impacto da Melhoria (Baseado no PRD)**

A implementação exigirá modificações e adições nas seguintes áreas do sistema:

* **Frontend:** A tela de gerenciamento de agentes (`Settings > Agents`) precisará de uma nova interface (botão e modal) para acionar os novos fluxos.
* **Backend:** A API precisará de novas rotas e lógica para:
    * Fornecer os "modelos pré-prontos" de agentes a partir do banco de dados.
    * Reutilizar a integração existente com a OpenAI para gerar as instruções.
* **Configuração:** Uma nova área na seção `Super Admin` será necessária para gerenciar o prompt do "Captain".
* **Banco de Dados:** Uma nova tabela (`agent_templates`) será criada para armazenar os modelos de agentes.

**3. Arquitetura de Alto Nível e Pontos de Integração**

1.  O **usuário** clica em "Adicionar novo Agente" na interface Vue.js.
2.  Um **novo modal** no frontend apresenta as opções: "Usar Modelo" ou "Criar do Zero".
3.  Se "Usar Modelo" for escolhido, o frontend busca os modelos da nova tabela `agent_templates` através de um novo endpoint da API Rails.
4.  Na tela de edição do agente, o botão "Criar instruções com IA" abre o modal do "Captain".
5.  O "Captain" interage com o usuário e envia o contexto para a API Rails, que utiliza o **serviço de integração da OpenAI já existente** para gerar o texto das instruções.
6.  As instruções geradas são salvas no campo correspondente do agente.
7.  O **Super Admin** poderá configurar o prompt do "Captain" através de uma nova interface na sua seção específica.

**4. Arquitetura de Dados**

Uma nova tabela será adicionada ao banco de dados PostgreSQL para armazenar os modelos.

* **Nome da Tabela:** `agent_templates`
* **Schema Proposto:**
    * `id` (primary key)
    * `name` (string, not null)
    * `description` (text)
    * `instructions` (text, not null) - O conteúdo do modelo de instrução.
    * `account_id` (foreign key, opcional, se os modelos forem por conta)
    * `created_at`, `updated_at` (timestamps)

**5. Integração com Serviços Externos**

* **Serviço:** OpenAI
* **Integração:** A funcionalidade "Captain" **deve reutilizar** o conector ou serviço de integração da OpenAI já existente no projeto. A análise sugere procurar por um service object como `::OpenAIService` ou `::Integrations::OpenAIConnector` no backend para encapsular as chamadas à API. Não será necessária uma nova integração.

**6. Estrutura de Arquivos e Módulos a Serem Modificados/Criados**

| Categoria | Arquivo/Diretório Provável | Ação Necessária |
| :--- | :--- | :--- |
| **BD - Migração** | `db/migrate/` | **Criar** nova migração para a tabela `agent_templates`. |
| **Backend - Modelo** | `app/models/agent_template.rb` | **Criar** novo modelo ActiveRecord para a tabela `agent_templates`. |
| **Backend - Roteamento**| `config/routes.rb` | **Adicionar** novas rotas para `agent_templates` na API e para a configuração do `captain` no Super Admin. |
| **Backend - Controlador**| `app/controllers/api/v1/accounts/agent_templates_controller.rb` | **Criar** novo controlador para servir os modelos de agente (ação `index`). |
| **Backend - Controlador**| `app/controllers/api/v1/accounts/agents_controller.rb` | **Modificar** para integrar com o serviço da OpenAI ao gerar instruções. |
| **Backend - Super Admin**| `app/controllers/super_admin/app_config_controller.rb` | **Modificar** para salvar e servir a configuração do prompt "Captain". |
| **Frontend - Componentes**| `app/javascript/dashboard/routes/dashboard/settings/agents/` | **Modificar/Criar** componentes Vue.js para o novo fluxo (modal de seleção, botão "Criar com IA", etc.). |
| **Frontend - API Client**| `app/javascript/dashboard/api/agents.js` | **Modificar** para adicionar chamadas aos novos endpoints. |
| **Frontend - Super Admin**| `app/javascript/dashboard/routes/super-admin/` | **Criar** uma nova view para o formulário de configuração do prompt do "Captain". |

**7. Dívida Técnica e Pontos de Atenção**

* **Consistência da UI/UX:** Os novos elementos de interface (modais, botões) devem seguir rigorosamente o Design System existente no Chatwoot para manter a consistência visual e de usabilidade.
* **Segurança:** O novo endpoint para a configuração do "Captain" no Super Admin deve ser devidamente protegido para garantir que apenas usuários autorizados possam acessá-lo.

