# Gestão de Ativos no Active Directory com PowerShell  

Um script poderoso para simplificar a gestão de ativos de TI no seu domínio Active Directory! Com uma interface amigável e interativa, este script permite listar equipamentos por setor, usuário, identificar dispositivos associados a usuários inativos e exportar relatórios detalhados em CSV. Ideal para administradores de rede que buscam eficiência e organização.

## Funcionalidades do Script  
- **Listagem por Setor**: Agrupa equipamentos por departamento ou unidade organizacional (OU).  
- **Associação por Usuário**: Relaciona dispositivos aos usuários com base em logons ou nomes de máquinas.  
- **Filtro de Usuários Inativos**: Identifica e separa equipamentos associados a contas desativadas no AD.  
- **Exportação de Relatórios**: Gera relatórios completos em CSV com informações como nome do computador, sistema operacional, último logon, setor e status do usuário.  
- **Interface Intuitiva**: Menu interativo para facilitar a navegação e execução das tarefas.

## Benefícios  
- **Automatize Tarefas**: Economize tempo com inventários automáticos e organizados.  
- **Reduza Erros**: Minimize falhas humanas com relatórios consistentes e precisos.  
- **Aumente a Eficiência**: Gere listagens detalhadas em minutos, sem necessidade de ferramentas complexas.  
- **Centralize o Gerenciamento**: Controle ativos de forma centralizada e prática.  
- **Escalabilidade**: Adaptável a redes de qualquer tamanho, de pequenas empresas a grandes corporações.

## Pré-requisitos  
- **PowerShell**: Versão 5.1 ou superior (padrão no Windows).  
- **Módulo Active Directory**: Instale via `Install-WindowsFeature RSAT-AD-PowerShell` (Windows Server) ou `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` (Windows 10/11).  
- **Permissões**: Execute como administrador com acesso ao domínio Active Directory.

## Como Usar  

### Clonando o Repositório  
1. Clone este repositório:  
   ```bash
   git clone https://github.com/danielfrade/gestaoativo.git
   ```  

### Executando o Script  
1. Abra o PowerShell como administrador.  
2. Navegue até o diretório do script:  
   ```powershell
   cd caminho\para\gestaoativos
   ```  
3. Execute o script:  
   ```powershell
   .\GestaoAtivos.ps1
   ```  
4. Siga o menu interativo para escolher as opções desejadas (listagem por setor, usuário, usuários inativos ou exportação de relatório).  

## Estrutura do Projeto  
- `GestaoAtivos.ps1`: Script principal com todas as funcionalidades.  
- `README.md`: Documentação detalhada do projeto.  

## Exemplos de Uso  
- **Listar Equipamentos por Setor**: Escolha a opção 1 no menu para visualizar dispositivos agrupados por departamento ou OU.  
- **Identificar Usuários Inativos**: Opção 3 exibe equipamentos associados a contas desativadas no AD.  
- **Exportar Relatório**: Use a opção 4 para gerar um CSV com todos os dados coletados, pronto para análises detalhadas.

## Contribuindo  
Contribuições são bem-vindas! Siga os passos abaixo:  
1. Faça um fork do projeto.  
2. Crie uma branch para sua melhoria:  
   ```bash
   git checkout -b feature/nova-funcionalidade
   ```  
3. Commit suas mudanças:  
   ```bash
   git commit -m 'Adicionando nova funcionalidade'
   ```  
4. Faça push para a branch:  
   ```bash
   git push origin feature/nova-funcionalidade
   ```  
5. Abra um Pull Request.  

## Notas  
- Certifique-se de que o ambiente tem conectividade com o controlador de domínio para consultar o Active Directory.  
- Algumas funcionalidades (como associação de usuário via WMI) podem requerer ajustes de firewall ou permissões adicionais.  
- Para redes muito grandes, considere ajustar os filtros de consulta ao AD para melhorar a performance.

Transforme a gestão de ativos do seu domínio com automação inteligente! 🚀
