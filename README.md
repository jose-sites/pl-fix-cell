# PL Fix Cell

Landing page, vitrine de produtos e painel administrativo da PL Fix Cell.

## O que enviar ao GitHub

Envie esta pasta inteira (`sua-assistencia-site`), mantendo esta estrutura:

- `.openai/` — configuração da hospedagem atual;
- `dist/` — site pronto para publicação;
- `supabase/` — banco de dados e função da IA;
- `README.md` — este guia.

Não envie chaves privadas. A chave da Groq deve continuar cadastrada somente em **Supabase > Edge Functions > Secrets**.

## Criar o repositório no GitHub

1. Entre em <https://github.com/new>.
2. Escolha um nome, por exemplo `pl-fix-cell`.
3. Crie o repositório vazio, sem adicionar README, `.gitignore` ou licença.
4. Abra um terminal dentro desta pasta e execute:

```bash
git remote add github https://github.com/SEU-USUARIO/pl-fix-cell.git
git push -u github main
```

Troque `SEU-USUARIO` pelo nome da sua conta no GitHub.

## Abrir localmente

O site público está em `dist/index.html`, a vitrine em `dist/produtos.html` e o painel em `dist/admin.html`.

