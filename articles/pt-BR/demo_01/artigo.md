# 🚀 CI/CD com Microsoft Fabric na prática | AzureDevOps | YAML | Fabric REST APIs

Este artigo vem complementar o vídeo publicado no canal onde trouxemos um exemplo com abordagem prática de CI/CD no Microsoft Fabric.

```html
<iframe width="560" height="315" src="https://www.youtube.com/embed/KiQYkk7_lis?si=VyY-j6O4ZgVUXlch" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe> 
``` 

<a href="https://youtu.be/KiQYkk7_lis" target="_blank">
    <img src="articles/pt-BR/demo_01/assets/thumb_video.png"
        alt="🚀 CI/CD com Microsoft Fabric na prática | AzureDevOps | YAML | Fabric REST APIs"
        style="width:100%; max-width:560px: height=auto;"
    >
</a>

### 🚀 CI/CD com Microsoft Fabric na prática | AzureDevOps | YAML | Fabric REST APIs  

Nós construímos um exemplo utilizando:
- Data Pipeline;
- Notebook Spark;
- Lakehouse;
- Semantic model em Driect Lake
- Report  

O vídeo demonstrou o desenvolvimento entre os estágios de DEV, TESTE e PRODUÇÃO integrando os Workspaces do Microsoft Fabric, Repositórios e Pipelines YAML  no Azure Devops e também versionando com o repositório Git Local.

Manipulando scripts Power Shell e APIs REST do Fabric executamos ações de criação de itens no Fabric, alteração de GUID's, testes dos modelos e ainda o deploy automatizado após o merge das versões publicadas. 

### O que é CI/CD? Como pdemos aplicá-lo ao Microsoft Fabric  

CI/CD é uma abordagem moderna no desenvolvimento de software que significa "Integração Contínua" (Continuous Integration) e "Implantação Contínua" (Continuous Delivery/Deployment). Em resumo:

**Integração Contínua (CI)**: É o processo de integrar frequentemente as alterações de código feitas por diferentes desenvolvedores em um repositório central (como o Git). O objetivo é detectar erros rapidamente, automatizando testes e validações a cada mudança submetida.

**Entrega Contínua (CD)**: Vai além da CI, garantindo que o código testado esteja sempre pronto para ser implantado em produção manualmente, com processos automatizados até a etapa final.

**Implantação Contínua (CD)**: Uma extensão da entrega contínua, onde cada alteração que passa nos testes é automaticamente implantada em produção, sem intervenção manual.

Trazendo esta abordagem ao Microsoft Fabric, podemos automatizar e gerenciar o ciclo de vida de desenvolvimento, teste e implantação de soluções analíticas, como pipelines de dados, relatórios Power BI, notebooks e outros artefatos suportados pela plataforma. O Fabric, sendo uma solução unificada de análise de dados da Microsoft, possui integração com Git e pipelines de implantação para suportar práticas de DevOps, permitindo colaboração eficiente, controle de versão e entregas rápidas e confiáveis.  


> **Benefícios no Microsoft Fabric:**  
> - Colaboração: Vários desenvolvedores trabalham simultaneamente sem conflitos, usando controle de versão. 
> - Qualidade: Testes automatizados detectam problemas mais rapidamente.  
> - Agilidade: Implantações rápidas e consistentes aceleram a entrega.
> - Consistência: Ambientes refletem fielmente o código versionado, evitando "desvios de configuração".  
> - Segurança: Permite que qualquer estágio seja revertido quando necessário. 

## Exemplo prático  

Vejamos o esquema abaixo.  

![Schema](./assets/schema.png)  

Este esquema ilustra o processo que executamos no vídeo relacionado. 
Podemos ver claramente os três worskpaces em destaque: **DEV, TEST e PROD**
Estes mesmos workspaces estão sincronizados com os branches do repositóriono Azure DevOps: **DEV, TEST e MAIN**, respectivamente. 





