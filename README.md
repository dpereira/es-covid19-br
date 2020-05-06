# es-covid19-br

Empacota os dados de [turicas/covid19-br](https://github.com/turicas/covid19-br) em uma instância Kibana/Elasticsearch,
facilitando acesso e consulta.

## Licenças

Os scripts neste repositório se encontram sob [Apache License v2.0](https://www.apache.org/licenses/LICENSE-2.0), mas os dados carregados
são distribuídos pela licensa descrita em [turicas/covid19-br](https://github.com/turicas/covid19-br#licen%C3%A7a).

Caso inclua visualizações que usam estes dados em algum projeto, atente para as condições de uso e
distribuição destes dados.

## Dependências

Você irá precisar de:
 - docker 19+
 - node 10+
 - npm
 - python 3+
 - curl
 - sudo

```
$ make setup
```

Isto deve dar conta de instalar todas as ferramentas adicionais necessárias, e baixar
os dados a partir dos [datasets.](https://data.brasil.io/dataset/covid19/_meta/list.html)

Este projeto foi apenas testado em Linux, e precisa de uma configuração de sistema
para que o Elasticsearch rode corretamente sobre Docker. Esta config talvez não seja
necessária para outros ambientes, mas é preciso testar e adequar o Makefile para que
funcionem neles.

## Usando

Após o setup inicial, você pode:

```
$ make run
```

Serão inicializados containeres Elasticsearch e Kibana, sendo os dados
populados em índices do Elasticsearch via Logstash logo em seguida.

Terminada a inclusão dos dados no Elasticsearch, você pode importar alguns dashboards,
visualizações e queries que vêm junto com o repositório com:

```
$ make import-kibana
```

E, finalmente, acessar o Kibana: http://localhost:5601.

Caso não tenha familiaridade no uso do Kibana, você pode consultar a documentação da Elastic,
incluída na seção de [Referências](#Referências), abaixo.

![](doc/img/states.png)

## Atualizando os dados

Caso você queira atualizar os dados com a ultima versão disponível, você poderia executar:

```
$ make update-data
```

Mas note que isto irá também resetar as configurações de objetos salvos no Kibana,
ou seja, dashboards, queries, visualizações, etc.

Para que você não perca seus dashboards e queries, você pode rodar a seguinte seqüência de targets:

```
$ make export-kibana
$ make update-data
$ make import-kibana
```

Recarregue o Kibana, caso o tenha aberto no browser (full reload), para que as alterações façam efeito.

Se você quiser executar a coleta localmente, ao invés de baixar os dados já consolidados, pode rodar:

```
$ make export-kibana recollect-data run 
$ make import-kibana
```

E recarregar a aplicação no browser da mesma forma.

## Configurando

A ingestão dos dados é feita no Elasticsearch em um índice por arquivo .csv gerado pelo projeto de coleta (covid19-br).
Para um dado arquivo `nome.csv` é criado um índice chamado `nome` no Elasticsearch. Para que as queries e dashboards funcionem bem, é preciso
prover _mappings_ para que os dados sejam interpretados corretamente pelo Elasticsearch. Um mapping de exemplo para o arquivo/índice
de casos (`caso.csv`/`caso`) é incluído no diretório `index-templates`, com o nome `caso.json`. Outros templates com os mappings necessários
podem ser incluídos neste diretório, seguindo a convenção `nome.json`, onde `nome` é o nome do índice/arquivo .csv.

Pode ser também necessária a customização do pipeline ou dos filtros usados pelo logstash usado na ingestão dos dados.
Esta configuração se encontra no arquivo `logstash/logstash.conf`

## Contribuindo

Contribuições de código podem ser feitas via PR normalmente.

Caso deseje incluir ou modificar algum dashboard, query, visualização ou qualquer
dado relacionado ao Kibana, localize ou crie um diretório adequado para sua alteração
no diretório `saved-objects`. [Exporte](https://www.elastic.co/guide/en/kibana/current/managing-saved-objects.html) 
os objetos relevantes do Kibana para a sua alteração,
neste diretório, faça um commit com eles e envie um PR.

No PR, descreva a motivação e a alteração na maior quantidade de detalhes possível.

Você pode querer revisar as Issues que temos abertas.

## Referências

- Dados da Covid19 no Brasil.IO:
  - Datasets: https://brasil.io/dataset/covid19/caso/
  - Coleta: https://github.com/turicas/covid19-br
- Kibana: https://www.elastic.co/guide/en/kibana/7.6/index.html
- Elasticsearch: https://www.elastic.co/guide/en/elasticsearch/guide/master/index.html
- Logstash: https://www.elastic.co/guide/en/logstash/current/getting-started-with-logstash.html
