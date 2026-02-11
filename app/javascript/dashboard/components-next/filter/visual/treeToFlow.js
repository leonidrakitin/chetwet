/**
 * Converts a nested query tree (JSON) to Vue Flow nodes and edges.
 */

const NODE_WIDTH = 280;
const NODE_HEIGHT = 60;
const GROUP_PADDING = 20;
const VERTICAL_GAP = 80;
const HORIZONTAL_GAP = 40;

let nodeIdCounter = 0;

function resetCounter() {
  nodeIdCounter = 0;
}

function nextId() {
  nodeIdCounter += 1;
  return `node-${nodeIdCounter}`;
}

export function treeToFlow(tree) {
  resetCounter();
  const nodes = [];
  const edges = [];

  if (!tree || !tree.type) return { nodes, edges };

  processNode(tree, nodes, edges, null, { x: 100, y: 50 });

  return { nodes, edges };
}

function processNode(node, nodes, edges, parentId, position) {
  const id = nextId();

  if (node.type === 'condition') {
    nodes.push({
      id,
      type: 'conditionNode',
      position: { ...position },
      data: {
        attributeKey: node.attributeKey || node.attribute_key,
        filterOperator: node.filterOperator || node.filter_operator,
        values: node.values,
        attributeModel: node.attributeModel || node.attribute_model || 'standard',
      },
    });
  } else if (node.type === 'group') {
    const children = node.children || [];

    nodes.push({
      id,
      type: 'groupNode',
      position: { ...position },
      data: {
        operator: node.operator,
        childCount: children.length,
      },
    });

    let childX = position.x;
    const childY = position.y + NODE_HEIGHT + VERTICAL_GAP;

    children.forEach((child, index) => {
      const childId = processNode(child, nodes, edges, id, {
        x: childX,
        y: childY,
      });

      edges.push({
        id: `edge-${id}-${childId}`,
        source: id,
        target: childId,
        type: 'operatorEdge',
        data: { operator: node.operator },
        animated: true,
      });

      childX += NODE_WIDTH + HORIZONTAL_GAP;
    });
  }

  if (parentId) {
    // Edge already created by parent
  }

  return id;
}

/**
 * Estimates the width needed for a subtree (for layout purposes).
 */
export function estimateSubtreeWidth(node) {
  if (!node) return NODE_WIDTH;
  if (node.type === 'condition') return NODE_WIDTH;
  if (node.type === 'group' && node.children) {
    const childWidths = node.children.map(c => estimateSubtreeWidth(c));
    return childWidths.reduce((sum, w) => sum + w + HORIZONTAL_GAP, -HORIZONTAL_GAP);
  }
  return NODE_WIDTH;
}
