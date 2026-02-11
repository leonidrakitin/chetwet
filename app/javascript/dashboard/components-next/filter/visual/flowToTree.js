/**
 * Converts Vue Flow nodes and edges back to a nested query tree (JSON).
 */

export function flowToTree(nodes, edges) {
  if (!nodes.length) return null;

  // Build adjacency map: parent -> children
  const childrenMap = {};
  const childIds = new Set();

  edges.forEach(edge => {
    if (!childrenMap[edge.source]) {
      childrenMap[edge.source] = [];
    }
    childrenMap[edge.source].push(edge.target);
    childIds.add(edge.target);
  });

  // Find root: node that is never a target
  const rootNode = nodes.find(n => !childIds.has(n.id));
  if (!rootNode) return null;

  return buildTreeFromNode(rootNode, nodes, childrenMap);
}

function buildTreeFromNode(node, allNodes, childrenMap) {
  if (node.type === 'conditionNode') {
    return {
      type: 'condition',
      attributeKey: node.data.attributeKey,
      filterOperator: node.data.filterOperator,
      values: node.data.values,
      attributeModel: node.data.attributeModel || 'standard',
    };
  }

  if (node.type === 'groupNode') {
    const childNodeIds = childrenMap[node.id] || [];
    const nodesById = Object.fromEntries(allNodes.map(n => [n.id, n]));

    const children = childNodeIds
      .map(childId => nodesById[childId])
      .filter(Boolean)
      .map(childNode => buildTreeFromNode(childNode, allNodes, childrenMap));

    return {
      type: 'group',
      operator: node.data.operator || 'and',
      children,
    };
  }

  return null;
}
