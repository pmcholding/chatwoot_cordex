### **Título do Épico**

Fluxo de Criação de Agente Assistido por IA - Aprimoramento Brownfield

### **Objetivo do Épico**

Simplificar o processo de criação de novos agentes de IA e melhorar a qualidade de suas instruções, fornecendo opções de configuração baseadas em modelos e assistência de IA.

### **Descrição do Épico**

**Contexto do Sistema Existente:**
* **Funcionalidade Relevante Atual:** O sistema `chatwoot_cordex` permite a criação manual de agentes através da seção de configurações.
* **Pilha de Tecnologia:** O backend utiliza Ruby on Rails com um banco de dados PostgreSQL, e o frontend é construído com Vue.js.
* **Pontos de Integração:** O trabalho se integrará ao fluxo de criação de agentes existente (`AgentsController`, componentes Vue de gerenciamento de agentes) e reutilizará um serviço de integração OpenAI existente.

**Detalhes do Aprimoramento:**
* **O que está sendo adicionado/alterado:** Um novo fluxo de criação de agentes será introduzido, oferecendo duas opções: "Usar Modelo" e "Criar do Zero". Adicionalmente, uma ferramenta assistida por IA ("Captain") será adicionada à tela de edição do agente para gerar instruções. Uma nova tabela de banco de dados, `agent_templates`, será criada para armazenar os modelos.
* **Como se integra:** A nova funcionalidade será acionada a partir da tela de gerenciamento de agentes. Novos endpoints de API serão criados para servir os modelos e para o "Captain". A interface do Super Admin será estendida para permitir a configuração do prompt do "Captain".
* **Critérios de Sucesso:** Aumento da taxa de satisfação do usuário ao criar agentes e uma melhoria perceptível na qualidade das instruções dos agentes criados através do novo fluxo.

### **Histórias**

1.  **História 1: Backend e Banco de Dados para Modelos de Agente:** Implementar o backend necessário para os modelos de agente, incluindo a migração do banco de dados para a tabela `agent_templates`, o modelo ActiveRecord e o endpoint da API para listar os modelos disponíveis.
2.  **História 2: Frontend para Seleção de Modelo:** Modificar a interface do usuário de gerenciamento de agentes para incluir um novo modal que oferece as opções "Usar Modelo" e "Criar do Zero", consumindo o novo endpoint da API para exibir os modelos.
3.  **História 3: Integração do "Captain" para Geração de Instruções:** Adicionar o botão "Criar instruções com IA" na tela de edição do agente, implementar o modal de interação e conectar ao backend para reutilizar o serviço OpenAI existente para gerar e salvar as instruções do agente.

### **Requisitos de Compatibilidade**

* [x] As APIs existentes devem permanecer inalteradas para não quebrar integrações atuais.
* [x] As alterações no esquema do banco de dados devem ser aditivas (nova tabela) e compatíveis com versões anteriores.
* [x] As alterações na UI devem seguir os padrões de design e componentes existentes do Chatwoot.
* [x] O impacto no desempenho deve ser mínimo.

### **Mitigação de Riscos**

* **Risco Principal:** Quebrar o fluxo de criação de agente manual existente.
* **Mitigação:** Cobertura de testes abrangente para o fluxo de criação de agente existente e novo. A nova funcionalidade deve ser desenvolvida de forma a não interferir no caminho do código do fluxo manual.
* **Plano de Reversão:** As alterações podem ser revertidas desativando a rota da nova funcionalidade e revertendo a migração do banco de dados, se necessário.

### **Definição de Pronto (Definition of Done)**

* [ ] Todas as histórias concluídas com os critérios de aceitação atendidos.
* [ ] A funcionalidade existente de criação manual de agente foi verificada por meio de testes e continua funcionando corretamente.
* [ ] Os novos pontos de integração estão funcionando corretamente.
* [ ] A documentação interna para a nova tabela e endpoints foi atualizada.
* [ ] Nenhuma regressão nas funcionalidades existentes foi introduzida.

---

### **Handoff para o Gerente de Histórias (Story Manager):**

"Por favor, desenvolva histórias de usuário detalhadas para este épico brownfield.
**Considerações Chave:**

* Este é um aprimoramento para um sistema existente executando Ruby on Rails e Vue.js.
* **Pontos de Integração:** `agents_controller.rb`, componentes Vue em `settings/agents/`, e a reutilização de um serviço OpenAI existente.
* **Padrões Existentes a Seguir:** Padrões de API do Rails e componentes Vue do Chatwoot.
* **Requisitos Críticos de Compatibilidade:** A funcionalidade de criação de agente manual existente não deve ser afetada.
* Cada história deve incluir a verificação de que a funcionalidade existente permanece intacta.

O épico deve manter a integridade do sistema enquanto entrega o objetivo de simplificar a criação de agentes."