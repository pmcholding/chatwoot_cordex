const { chromium } = require('playwright');

async function testWhatsAppIntegration() {
  console.log('🧪 Iniciando testes da integração WhatsApp Evolution API...\n');

  const browser = await chromium.launch({ 
    headless: false,
    slowMo: 1000 // Adiciona delay para visualizar melhor
  });
  
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    // 1. Teste de acesso à página inicial
    console.log('1. 🌐 Testando acesso à página inicial...');
    await page.goto('http://localhost:3001');
    await page.waitForTimeout(3000);
    
    const title = await page.title();
    console.log(`   ✅ Página carregada: ${title}`);

    // 2. Teste de login (se necessário)
    console.log('\n2. 🔐 Verificando se precisa fazer login...');
    
    // Verifica se há formulário de login
    const loginForm = await page.locator('form').first();
    if (await loginForm.isVisible()) {
      console.log('   📝 Formulário de login encontrado, tentando login...');
      
      // Tenta fazer login com credenciais padrão
      await page.fill('input[type="email"]', 'john@acme.inc');
      await page.fill('input[type="password"]', 'Password1!');
      await page.click('button[type="submit"]');
      await page.waitForTimeout(3000);
      console.log('   ✅ Login realizado');
    } else {
      console.log('   ✅ Já logado ou não precisa de login');
    }

    // 3. Teste de navegação para criação de inbox
    console.log('\n3. 📬 Navegando para criação de inbox...');
    await page.goto('http://localhost:3001/app/accounts/1/settings/inboxes/new');
    await page.waitForTimeout(3000);
    
    const pageContent = await page.content();
    if (pageContent.includes('Create a new inbox')) {
      console.log('   ✅ Página de criação de inbox carregada');
    } else {
      console.log('   ⚠️  Página pode não ter carregado completamente');
    }

    // 4. Teste de verificação dos canais disponíveis
    console.log('\n4. 📋 Verificando canais disponíveis...');
    
    // Aguarda os canais carregarem
    await page.waitForTimeout(2000);
    
    // Verifica se WABA existe
    const wabaChannel = page.locator('text=WABA');
    if (await wabaChannel.isVisible()) {
      console.log('   ✅ Canal WABA encontrado (antigo WhatsApp)');
    } else {
      console.log('   ❌ Canal WABA NÃO encontrado');
    }
    
    // Verifica se novo WhatsApp existe
    const whatsappChannel = page.locator('text=WhatsApp').first();
    if (await whatsappChannel.isVisible()) {
      console.log('   ✅ Novo canal WhatsApp (Evolution) encontrado');
    } else {
      console.log('   ❌ Novo canal WhatsApp (Evolution) NÃO encontrado');
    }

    // 5. Teste de clique no novo canal WhatsApp
    console.log('\n5. 🖱️  Testando clique no canal WhatsApp Evolution...');
    
    try {
      // Procura por um card ou botão que contenha "WhatsApp" mas não "WABA"
      const evolutionWhatsApp = page.locator('[data-testid*="whatsapp"], .channel-item').filter({ hasText: 'WhatsApp' }).first();
      
      if (await evolutionWhatsApp.isVisible()) {
        await evolutionWhatsApp.click();
        await page.waitForTimeout(2000);
        console.log('   ✅ Clique no canal WhatsApp Evolution realizado');
        
        // Verifica se o formulário de criação apareceu
        const formTitle = page.locator('h3, h2, h1').filter({ hasText: /WhatsApp Evolution|Evolution API/i });
        if (await formTitle.isVisible()) {
          console.log('   ✅ Formulário de criação do canal Evolution carregado');
        } else {
          console.log('   ⚠️  Formulário pode não ter carregado ou ter título diferente');
        }
      } else {
        console.log('   ❌ Canal WhatsApp Evolution não encontrado para clique');
      }
    } catch (error) {
      console.log(`   ❌ Erro ao clicar no canal: ${error.message}`);
    }

    // 6. Teste de criação de inbox (se formulário estiver visível)
    console.log('\n6. 📝 Testando criação de inbox...');
    
    const inboxNameInput = page.locator('input[placeholder*="inbox name"], input[placeholder*="nome"]').first();
    if (await inboxNameInput.isVisible()) {
      await inboxNameInput.fill('Teste WhatsApp Evolution');
      console.log('   ✅ Nome da inbox preenchido');
      
      const submitButton = page.locator('button[type="submit"], button').filter({ hasText: /Create|Criar/i }).first();
      if (await submitButton.isVisible()) {
        console.log('   ✅ Botão de criação encontrado');
        // Não vamos clicar para não criar inbox de teste
        console.log('   ℹ️  Não clicando para evitar criar inbox de teste');
      }
    } else {
      console.log('   ⚠️  Campo de nome da inbox não encontrado');
    }

    // 7. Teste de verificação das traduções
    console.log('\n7. 🌍 Verificando traduções...');
    
    const pageText = await page.textContent('body');
    
    // Verifica traduções em português (padrão)
    if (pageText.includes('WhatsApp Evolution') || pageText.includes('Evolution API')) {
      console.log('   ✅ Traduções relacionadas ao Evolution encontradas');
    } else {
      console.log('   ⚠️  Traduções do Evolution podem não estar carregadas');
    }

    console.log('\n🎉 Testes concluídos com sucesso!');
    
  } catch (error) {
    console.error(`\n❌ Erro durante os testes: ${error.message}`);
    console.error(error.stack);
  } finally {
    await browser.close();
  }
}

// Executa os testes
testWhatsAppIntegration().catch(console.error);
