#!/bin/bash
set -e

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up local Graph Node for Babylon chain debugging${NC}"

# PostgreSQL configuration
DB_NAME="graph_node_babylon"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# Check if PostgreSQL is running
if ! pg_isready -h $DB_HOST -p $DB_PORT > /dev/null 2>&1; then
  echo -e "${RED}Error: PostgreSQL is not running on $DB_HOST:$DB_PORT${NC}"
  echo "Please make sure PostgreSQL is installed and running."
  echo "You can install it with:"
  echo "  brew install postgresql@14"
  echo "  brew services start postgresql@14"
  exit 1
fi

# Create database if it doesn't exist
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
  echo -e "${BLUE}Creating database '$DB_NAME'...${NC}"
  createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
  echo -e "${GREEN}Database created successfully!${NC}"
else
  echo -e "${GREEN}Database '$DB_NAME' already exists${NC}"
fi

# Create config directory
CONFIG_DIR="./babylon-graph-node-config"
mkdir -p $CONFIG_DIR

# Create config file for Graph Node
CONFIG_FILE="$CONFIG_DIR/config.toml"
echo -e "${BLUE}Creating Graph Node configuration file...${NC}"
cat > $CONFIG_FILE << EOF
[deployment]
[[deployment.rule]]
shard = "primary"
indexers = [ "index_node_cosmos_1" ]

[store]
[store.primary]
connection = "postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
pool_size = 10

[chains]
ingestor = "block_ingestor_node"

[chains.babylon]
shard = "primary"
protocol = "substreams"
provider = [
  { label = "babylon", details = { type = "substreams", url = "http://159.89.170.65:10016" }},
]
EOF

echo -e "${GREEN}Configuration file created at $CONFIG_FILE${NC}"
echo "Contents of the configuration file:"
cat $CONFIG_FILE

# Check if graph-node is installed
if ! command -v graph-node &> /dev/null; then
  echo -e "${BLUE}Graph Node binary not found${NC}"
  echo "Please install Graph Node from source:"
  echo "  git clone https://github.com/graphprotocol/graph-node.git"
  echo "  cd graph-node"
  echo "  cargo build --release"
  echo "  Add the binary to your PATH or provide the full path below"
  
  read -p "Enter the path to the graph-node binary or press Enter to exit: " GRAPH_NODE_PATH
  
  if [ -z "$GRAPH_NODE_PATH" ]; then
    echo -e "${RED}No path provided. Exiting.${NC}"
    exit 1
  fi
  
  if [ ! -f "$GRAPH_NODE_PATH" ]; then
    echo -e "${RED}Invalid path. File does not exist. Exiting.${NC}"
    exit 1
  fi
else
  GRAPH_NODE_PATH="graph-node"
fi

# Run Graph Node
echo -e "${BLUE}Starting Graph Node for Babylon chain...${NC}"
echo "Press Ctrl+C to stop"

$GRAPH_NODE_PATH \
  --config $CONFIG_FILE \
  --node-id index_node_cosmos_1

echo -e "${GREEN}Graph Node stopped${NC}" 