# Persistence Graph Node Setup

The graph node setup is running on a digitalocean managed kubernetes cluster and consists of

- IPFS Node
- Firehose Node
- Graph Node

## How to run

### Prerequisistes

- Kubernetes cluster and `kubectl` - [How to install](https://kubernetes.io/docs/tasks/tools/)
- Postgres
  - [Digital Ocean Managed DB](https://docs.digitalocean.com/products/databases/postgresql/)
  - Running Locally? [Download](https://www.postgresql.org/download/)

> **Note**  
> Install [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) to run local kubernetes cluster.  
> This setup is using Digital Ocean's `do-block-storage` storage class for PVC (Persistent Volume Claim). Change it if you have different PVC storage class for your cluster. (`standard` for local kind cluster)

`graph-node` uses a few Postgres extensions. If the Postgres user with which
you run `graph-node` is a superuser, `graph-node` will enable these
extensions when it initalizes the database. If the Postgres user is not a
superuser, you will need to create the extensions manually since only
superusers are allowed to do that. To create them you need to connect as a
superuser, which in many installations is the `postgres` user:

```bash
    psql -q -X -U <SUPERUSER> graph-node <<EOF
create extension pg_trgm;
create extension pg_stat_statements;
create extension btree_gist;
create extension postgres_fdw;
grant usage on foreign data wrapper postgres_fdw to <USERNAME>;
EOF

```

### Update Config Map

There are three setups: (under `networks` folder)

- devnet
- testnet
- mainnet

Each setup has it's `configmap.yaml` which consists of three ConfigMaps:

1. persistencecore
2. firehose-node-config
3. graph-node-config

> **Note**
> For `devnet` the configs can be used as is.

You need to update the

- `snapshot_restore_url` - make sure the snapshot is in `.tar.gz` format and created with `v6.1.0` persistence binary.
- `seeds`
- `first_streamable_block` - from what height to start streaming the blocks (should be greater then the snapshot height)
- `force_init` - use this only if you want to delete everything and start again. (Make sure to set it to `false` once done)

### Run

Use this command to apply the configs to your cluster

```bash
kubectl apply -k networks/devnet # change to the network you are using 
```

## How to upgrade

Make sure that the persistenceCore has the `fh` tag for the upgrade version.  
And it has the docker image published for the same tag.  
Ex. For `v6.1.0` it is `v6.1.0-fh`

Change the persistencecore image in `graph-node/firehose-node.yaml` file.  
And run `kubectl apply`.

## How to deploy a subgraph
NOTE: Ensure you have right kubeconfig for the testnet/mainnet setup in Digital Ocean. Also note that this is temporary setup. We plan to implement Auth based k8s setup as possible.    

### Steps  
1. Port forward below ports your local machine(same or any unused port):-   
    a) IPFS node: port 5001   
    b) Graph node: port 8020   
    example cmd:
    ```kubectl port-forward pod-name 5001:5001 --namespace graph-core-1)```   

2. To deploy a subgraph with its precise name, put & execute below steps in your package.json:-   
  ```
    "codegen": "graph codegen",
    "build": "graph build",
    "create-local": "graph create --node http://localhost:8020/ <subgraph-name>",
    "deploy-local": "graph deploy --node http://localhost:8020/ --ipfs http://localhost:5001 <subgraph-name>",
  ```   
3. Check the deployed subgraphs at respective GraphiQL endpoints:-   
GraphQL endpoint for testnet: https://graph.testnet.persistence.one   
GraphQL endpoint for mainnet: https://graph.mainnet.persistence.one   

