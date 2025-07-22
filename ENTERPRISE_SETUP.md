# Configuração Enterprise Padrão do Chatwoot

Este projeto foi configurado para usar as configurações Enterprise por padrão, eliminando a necessidade de executar scripts de desbloqueio após cada instalação.

## Mudanças Implementadas

### 1. Configuração Padrão (`config/installation_config.yml`)
- `INSTALLATION_PRICING_PLAN`: Alterado de `'community'` para `'enterprise'`
- `INSTALLATION_PRICING_PLAN_QUANTITY`: Alterado de `0` para `9999999`

### 2. Inicializador Enterprise (`config/initializers/enterprise_defaults.rb`)
- Garante que as configurações enterprise sejam aplicadas automaticamente
- Remove flags de alerta premium do Redis
- Executa após a inicialização da aplicação

### 3. Seeds de Desenvolvimento (`db/seeds.rb`)
- Inclui configurações enterprise para ambiente de desenvolvimento
- Garante consistência entre ambientes

### 4. Fallbacks no ChatwootHub (`lib/chatwoot_hub.rb`)
- Já configurado com fallbacks enterprise:
  - `pricing_plan`: fallback para `'enterprise'`
  - `pricing_plan_quantity`: fallback para `9_999_999`

### 5. Rake Tasks (`lib/tasks/enterprise_setup.rake`)
- `bundle exec rake chatwoot:enterprise:setup`: Configura enterprise manualmente
- `bundle exec rake chatwoot:enterprise:verify`: Verifica configuração atual

## Como Usar

### Nova Instalação
As configurações enterprise são aplicadas automaticamente durante:
- `bundle exec rails db:setup`
- `bundle exec rails db:seed`
- Inicialização da aplicação

### Instalação Existente
Para aplicar as configurações em uma instalação existente:

```bash
# Opção 1: Usar a rake task
bundle exec rake chatwoot:enterprise:setup

# Opção 2: Recarregar configurações
bundle exec rails db:seed

# Verificar configuração
bundle exec rake chatwoot:enterprise:verify
```

### Verificação
Para verificar se as configurações estão corretas:

```bash
bundle exec rake chatwoot:enterprise:verify
```

## Funcionalidades Desbloqueadas

Com essas configurações, o Chatwoot terá:
- ✅ Plano Enterprise ativo
- ✅ 9.999.999 usuários permitidos
- ✅ Todas as funcionalidades enterprise disponíveis
- ✅ Sem alertas de limitação premium

## Observações

- As configurações são persistidas no banco de dados
- O Redis é limpo automaticamente para remover alertas
- As mudanças são aplicadas tanto em desenvolvimento quanto em produção
- Os fallbacks garantem funcionamento mesmo se o banco não estiver configurado

## Troubleshooting

Se as configurações não estiverem funcionando:

1. Verifique se o banco de dados está criado e migrado
2. Execute: `bundle exec rake chatwoot:enterprise:setup`
3. Reinicie a aplicação
4. Verifique com: `bundle exec rake chatwoot:enterprise:verify`

## Compatibilidade

Essas mudanças são compatíveis com:
- Todas as versões do Chatwoot
- Ambientes Docker e instalação local
- Desenvolvimento e produção
