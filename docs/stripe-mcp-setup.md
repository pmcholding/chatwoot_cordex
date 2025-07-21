# Configuração do Stripe MCP (Model Context Protocol)

O Stripe MCP foi instalado com sucesso no projeto. Este documento explica como configurar e usar o servidor MCP do Stripe.

## Instalação

O pacote `@stripe/mcp` já foi instalado via pnpm:

```bash
pnpm add @stripe/mcp
```

## Configuração

### 1. Variáveis de Ambiente

Certifique-se de que as seguintes variáveis estão configuradas no seu `.env`:

```bash
# Chave secreta do Stripe (já configurada)
STRIPE_SECRET_KEY=sk_test_...

# Chave webhook do Stripe (já configurada)
STRIPE_WEBHOOK_SECRET=whsec_...
```

### 2. Uso Básico via CLI

Para executar o servidor MCP do Stripe usando npx:

```bash
# Configurar todas as ferramentas disponíveis
npx @stripe/mcp --tools=all --api-key=$STRIPE_SECRET_KEY

# Configurar ferramentas específicas
npx @stripe/mcp --tools=customers.create,customers.read,products.create --api-key=$STRIPE_SECRET_KEY

# Para conta conectada do Stripe
npx @stripe/mcp --tools=all --api-key=$STRIPE_SECRET_KEY --stripe-account=CONNECTED_ACCOUNT_ID
```

### 3. Configuração para Claude Desktop

Para usar com Claude Desktop, adicione ao `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "stripe": {
      "command": "npx",
      "args": [
          "-y",
          "@stripe/mcp",
          "--tools=all",
          "--api-key=STRIPE_SECRET_KEY"
      ]
    }
  }
}
```

### 4. Configuração com Docker

```json
{
    "mcpServers": {
        "stripe": {
            "command": "docker",
            "args": [
                "run",
                "--rm",
                "-i",
                "mcp/stripe",
                "--tools=all",
                "--api-key=STRIPE_SECRET_KEY"
            ]
        }
    }
}
```

## Ferramentas Disponíveis

O servidor MCP do Stripe oferece as seguintes ferramentas:

| Ferramenta | Descrição |
|------------|-----------|
| `customers.create` | Criar um novo cliente |
| `customers.read` | Ler informações do cliente |
| `products.create` | Criar um novo produto |
| `products.read` | Ler informações do produto |
| `prices.create` | Criar um novo preço |
| `prices.read` | Ler informações de preço |
| `paymentLinks.create` | Criar um novo link de pagamento |
| `invoices.create` | Criar uma nova fatura |
| `invoices.update` | Atualizar uma fatura existente |
| `invoiceItems.create` | Criar um novo item de fatura |
| `balance.read` | Recuperar informações de saldo |
| `refunds.create` | Criar um novo reembolso |
| `paymentIntents.read` | Ler informações de intenção de pagamento |
| `subscriptions.read` | Ler informações de assinatura |
| `subscriptions.update` | Atualizar informações de assinatura |
| `coupons.create` | Criar um novo cupom |
| `coupons.read` | Ler informações do cupom |
| `disputes.update` | Atualizar uma disputa existente |
| `disputes.read` | Ler informações de disputas |
| `documentation.read` | Pesquisar documentação do Stripe |

## Debug do Servidor

Para debugar o servidor MCP, use o MCP Inspector:

```bash
# Primeiro, construa o servidor
npm run build

# Execute o MCP Inspector
npx @modelcontextprotocol/inspector node dist/index.js --tools=all --api-key=$STRIPE_SECRET_KEY
```

### Com Docker

```bash
# Construa o servidor
docker build -t mcp/stripe .

# Execute com MCP Inspector
docker run -p 3000:3000 -p 5173:5173 -v /var/run/docker.sock:/var/run/docker.sock mcp/inspector docker run --rm -i mcp/stripe --tools=all --api-key=$STRIPE_SECRET_KEY
```

## Integração com o Sistema Atual

O projeto já possui integração com Stripe através de:

- **Controlador de Webhooks**: `enterprise/app/controllers/enterprise/webhooks/stripe_controller.rb`
- **Serviços de Billing**: `enterprise/app/services/enterprise/billing/`
- **Configuração**: `config/initializers/stripe.rb`

O MCP do Stripe complementa essa integração fornecendo uma interface padronizada para LLMs interagirem com a API do Stripe.

## Próximos Passos

1. Configure as variáveis de ambiente necessárias
2. Teste o servidor MCP usando o MCP Inspector
3. Integre com seu cliente MCP preferido (Claude Desktop, etc.)
4. Explore as ferramentas disponíveis para automatizar tarefas do Stripe

## Links Úteis

- [Documentação oficial do Stripe MCP](https://www.npmjs.com/package/@stripe/mcp)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Stripe Agent Toolkit](https://docs.stripe.com/agents)
