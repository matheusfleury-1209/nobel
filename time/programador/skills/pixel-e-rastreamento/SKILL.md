---
name: pixel-e-rastreamento
description: Configura e verifica o rastreamento de vendas (pixel da Meta na Hotmart, eventos de compra, parâmetros src/UTM e testes ponta a ponta) para que a Meta saiba quem comprou. Use quando campanhas não registram compras ou antes de rodar campanha de vendas.
---

# Pixel e rastreamento

1. **Diagnóstico:** a conta de anúncios recebe o evento `Purchase`? (conector da Meta: datasets/pixel e estatísticas; ou Gerenciador de Eventos). Registre o que existe.
2. **Hotmart:** no produto, em Configurações → Pixel de rastreamento, cadastrar o pixel da Meta (ID no PERFIL) com os eventos de checkout e compra. **Quem tem o acesso (o Matheus) faz**; você entrega o passo a passo com prints e confere depois.
3. **Página de vendas:** o pixel só carrega após o aceite de cookies. Mantenha (é o correto pela LGPD), mas garanta que o evento de compra venha da Hotmart, que não depende disso.
4. **Links:** padronize `src` por origem (`whatsapp-hanielly`, `whatsapp-rafa`, `pagina-asb`) e confira o cupom no parâmetro `offDiscount` quando houver oferta.
5. **Teste ponta a ponta:** compra de teste (ou evento de teste do Gerenciador de Eventos) → evento aparece na Meta → venda aparece no relatório da Hotmart com o `src` certo.
6. Registre em `empresa/tecnico/rastreamento.md` e avise a Gabi de que a campanha de vendas pode voltar (ou não).
