// Admin Panel JavaScript
const API_BASE = window.location.origin + '/api';
let authToken = localStorage.getItem('admin_token');
let currentFilters = {};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkAuth();
    setupEventListeners();
});

// Check authentication status
function checkAuth() {
    if (authToken) {
        // Verify token is still valid
        fetch(`${API_BASE}/admin/nodes?limit=1`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        })
        .then(res => {
            if (res.ok) {
                showAdminPanel();
            } else {
                handleAuthError();
            }
        })
        .catch(() => handleAuthError());
    } else {
        showLoginScreen();
    }
}

// Setup event listeners
function setupEventListeners() {
    document.getElementById('login-btn').addEventListener('click', handleLogin);
    document.getElementById('logout-btn').addEventListener('click', handleLogout);
    document.getElementById('apply-filters').addEventListener('click', applyFilters);
    document.getElementById('clear-filters').addEventListener('click', clearFilters);
    document.getElementById('close-edit-modal').addEventListener('click', closeEditModal);
    document.getElementById('cancel-edit').addEventListener('click', closeEditModal);
    document.getElementById('edit-form').addEventListener('submit', handleEditSubmit);
}

// Show login screen
function showLoginScreen() {
    document.getElementById('login-screen').style.display = 'block';
    document.getElementById('admin-panel').style.display = 'none';
}

// Show admin panel
function showAdminPanel() {
    document.getElementById('login-screen').style.display = 'none';
    document.getElementById('admin-panel').style.display = 'block';
    loadNodes();
    loadUserInfo();
}

// Handle login
async function handleLogin() {
    const errorDiv = document.getElementById('login-error');
    errorDiv.style.display = 'none';
    
    try {
        // Start OAuth flow
        const response = await fetch(`${API_BASE}/auth/social/start`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                provider: 'google',
                redirectUri: window.location.origin + '/admin'
            })
        });

        const data = await response.json();
        
        if (data.authorizationUrl) {
            // Redirect to Google OAuth
            window.location.href = data.authorizationUrl;
        } else if (data.authUrl) {
            // Fallback for different response format
            window.location.href = data.authUrl;
        } else {
            throw new Error(data.message || 'Failed to start OAuth');
        }
    } catch (error) {
        errorDiv.textContent = error.message || 'Login failed. Please try again.';
        errorDiv.style.display = 'block';
    }
}

// Handle OAuth callback (if code is in URL)
async function handleOAuthCallback() {
    const urlParams = new URLSearchParams(window.location.search);
    const code = urlParams.get('code');
    const error = urlParams.get('error');

    if (error) {
        const errorDiv = document.getElementById('login-error');
        errorDiv.textContent = 'Authentication failed: ' + error;
        errorDiv.style.display = 'block';
        // Remove error from URL
        window.history.replaceState({}, document.title, window.location.pathname);
        return;
    }

    if (code) {
        const errorDiv = document.getElementById('login-error');
        errorDiv.style.display = 'none';
        
        try {
            const response = await fetch(`${API_BASE}/auth/social/callback`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    provider: 'google',
                    code: code,
                    redirectUri: window.location.origin + '/admin'
                })
            });

            const data = await response.json();

            if (data.token) {
                authToken = data.token;
                localStorage.setItem('admin_token', authToken);
                
                // Check if user is admin
                const nodesRes = await fetch(`${API_BASE}/admin/nodes?limit=1`, {
                    headers: {
                        'Authorization': `Bearer ${authToken}`
                    }
                });

                if (nodesRes.ok) {
                    // Remove code from URL
                    window.history.replaceState({}, document.title, window.location.pathname);
                    showAdminPanel();
                } else if (nodesRes.status === 403) {
                    throw new Error('You do not have admin access. Please contact an administrator.');
                } else {
                    throw new Error('Failed to verify admin access');
                }
            } else {
                throw new Error(data.message || 'Failed to authenticate');
            }
        } catch (error) {
            errorDiv.textContent = error.message || 'Authentication failed';
            errorDiv.style.display = 'block';
            // Remove code from URL on error
            window.history.replaceState({}, document.title, window.location.pathname);
        }
    }
}

// Handle logout
function handleLogout() {
    if (authToken) {
        fetch(`${API_BASE}/auth/logout`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        }).catch(() => {
            // Ignore errors on logout
        });
    }
    
    authToken = null;
    localStorage.removeItem('admin_token');
    showLoginScreen();
}

// Handle auth error
function handleAuthError() {
    authToken = null;
    localStorage.removeItem('admin_token');
    showLoginScreen();
    document.getElementById('login-error').textContent = 'Session expired. Please login again.';
    document.getElementById('login-error').style.display = 'block';
}

// Load user info
async function loadUserInfo() {
    // We can decode the JWT token to get user info, or make an API call
    // For now, just show email from token if available
    try {
        const payload = JSON.parse(atob(authToken.split('.')[1]));
        document.getElementById('user-info').textContent = `Logged in as: ${payload.email || 'Admin'}`;
    } catch (e) {
        document.getElementById('user-info').textContent = 'Logged in as Admin';
    }
}

// Apply filters
function applyFilters() {
    currentFilters = {
        threadId: document.getElementById('filter-thread').value.trim() || undefined,
        authorId: document.getElementById('filter-author').value.trim() || undefined,
        isDeleted: document.getElementById('filter-deleted').value || undefined,
        moderationState: document.getElementById('filter-moderation').value || undefined,
        limit: parseInt(document.getElementById('filter-limit').value) || 50,
        offset: 0
    };
    
    loadNodes();
}

// Clear filters
function clearFilters() {
    document.getElementById('filter-thread').value = '';
    document.getElementById('filter-author').value = '';
    document.getElementById('filter-deleted').value = '';
    document.getElementById('filter-moderation').value = '';
    document.getElementById('filter-limit').value = '50';
    currentFilters = { limit: 50, offset: 0 };
    loadNodes();
}

// Load nodes
async function loadNodes() {
    const loading = document.getElementById('loading');
    const nodesList = document.getElementById('nodes-list');
    const paginationInfo = document.getElementById('pagination-info');
    
    loading.style.display = 'block';
    nodesList.innerHTML = '';
    
    try {
        const params = new URLSearchParams();
        if (currentFilters.threadId) params.append('threadId', currentFilters.threadId);
        if (currentFilters.authorId) params.append('authorId', currentFilters.authorId);
        if (currentFilters.isDeleted !== undefined) params.append('isDeleted', currentFilters.isDeleted);
        if (currentFilters.moderationState) params.append('moderationState', currentFilters.moderationState);
        params.append('limit', (currentFilters.limit || 50).toString());
        params.append('offset', (currentFilters.offset || 0).toString());

        const response = await fetch(`${API_BASE}/admin/nodes?${params}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        if (response.status === 401 || response.status === 403) {
            handleAuthError();
            return;
        }

        if (!response.ok) {
            throw new Error(`Failed to load nodes: ${response.statusText}`);
        }

        const data = await response.json();
        
        // Update pagination info
        const total = data.pagination?.total || 0;
        const limit = data.pagination?.limit || 50;
        const offset = data.pagination?.offset || 0;
        paginationInfo.textContent = `Showing ${offset + 1}-${Math.min(offset + limit, total)} of ${total}`;

        // Render nodes
        if (data.nodes && data.nodes.length > 0) {
            data.nodes.forEach(node => {
                nodesList.appendChild(createNodeCard(node));
            });
        } else {
            nodesList.innerHTML = '<div class="empty-state"><h3>No nodes found</h3><p>Try adjusting your filters</p></div>';
        }
    } catch (error) {
        nodesList.innerHTML = `<div class="error-message">Error loading nodes: ${error.message}</div>`;
    } finally {
        loading.style.display = 'none';
    }
}

// Create node card
function createNodeCard(node) {
    const card = document.createElement('div');
    card.className = 'node-card' + (node.isDeleted ? ' deleted' : '');
    
    const moderationBadge = node.moderationState 
        ? `<span class="badge badge-${node.moderationState}">${node.moderationState}</span>`
        : '';
    
    const deletedBadge = node.isDeleted 
        ? '<span class="badge badge-deleted">Deleted</span>'
        : '';

    card.innerHTML = `
        <div class="node-header">
            <div>
                <div class="node-id">ID: ${node.nodeId || 'N/A'}</div>
                <div class="node-meta">
                    <span>Thread: ${node.threadId || 'N/A'}</span>
                    <span>Author: ${node.author ? node.author.displayName : 'N/A'}</span>
                    <span>Created: ${new Date(node.createdAt).toLocaleString()}</span>
                </div>
            </div>
            <div>
                ${moderationBadge}
                ${deletedBadge}
            </div>
        </div>
        ${node.title ? `<div class="node-title">${escapeHtml(node.title)}</div>` : ''}
        ${node.textContent ? `<div class="node-content">${escapeHtml(node.textContent)}</div>` : ''}
        ${node.video && node.video.url ? `<div class="node-meta"><span>Video: ${node.video.url}</span></div>` : ''}
        <div class="node-actions">
            <button class="btn btn-primary btn-small" onclick="editNode('${node.nodeId}')">Edit</button>
            ${!node.isDeleted 
                ? `<button class="btn btn-danger btn-small" onclick="deleteNode('${node.nodeId}')">Delete</button>`
                : `<button class="btn btn-success btn-small" onclick="restoreNode('${node.nodeId}')">Restore</button>`
            }
        </div>
    `;
    
    return card;
}

// Edit node
async function editNode(nodeId) {
    try {
        const response = await fetch(`${API_BASE}/admin/nodes/${nodeId}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        if (!response.ok) {
            throw new Error('Failed to load node');
        }

        const node = await response.json();
        
        document.getElementById('edit-node-id').value = node.nodeId;
        document.getElementById('edit-title').value = node.title || '';
        document.getElementById('edit-text-content').value = node.textContent || '';
        document.getElementById('edit-moderation').value = node.moderationState || 'visible';
        document.getElementById('edit-is-deleted').checked = node.isDeleted || false;
        
        document.getElementById('edit-modal').style.display = 'flex';
    } catch (error) {
        alert('Error loading node: ' + error.message);
    }
}

// Handle edit submit
async function handleEditSubmit(e) {
    e.preventDefault();
    
    const nodeId = document.getElementById('edit-node-id').value;
    const updateData = {
        title: document.getElementById('edit-title').value || null,
        textContent: document.getElementById('edit-text-content').value || null,
        moderationState: document.getElementById('edit-moderation').value,
        isDeleted: document.getElementById('edit-is-deleted').checked
    };

    try {
        const response = await fetch(`${API_BASE}/admin/nodes/${nodeId}`, {
            method: 'PATCH',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(updateData)
        });

        if (response.status === 401 || response.status === 403) {
            handleAuthError();
            return;
        }

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.message || 'Failed to update node');
        }

        closeEditModal();
        loadNodes();
        showSuccess('Node updated successfully');
    } catch (error) {
        alert('Error updating node: ' + error.message);
    }
}

// Delete node
async function deleteNode(nodeId) {
    if (!confirm('Are you sure you want to delete this node?')) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE}/admin/nodes/${nodeId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        if (response.status === 401 || response.status === 403) {
            handleAuthError();
            return;
        }

        if (!response.ok) {
            throw new Error('Failed to delete node');
        }

        loadNodes();
        showSuccess('Node deleted successfully');
    } catch (error) {
        alert('Error deleting node: ' + error.message);
    }
}

// Restore node
async function restoreNode(nodeId) {
    try {
        const response = await fetch(`${API_BASE}/admin/nodes/${nodeId}/restore`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });

        if (response.status === 401 || response.status === 403) {
            handleAuthError();
            return;
        }

        if (!response.ok) {
            throw new Error('Failed to restore node');
        }

        loadNodes();
        showSuccess('Node restored successfully');
    } catch (error) {
        alert('Error restoring node: ' + error.message);
    }
}

// Close edit modal
function closeEditModal() {
    document.getElementById('edit-modal').style.display = 'none';
    document.getElementById('edit-form').reset();
}

// Show success message
function showSuccess(message) {
    const successDiv = document.createElement('div');
    successDiv.className = 'success-message';
    successDiv.textContent = message;
    successDiv.style.position = 'fixed';
    successDiv.style.top = '20px';
    successDiv.style.right = '20px';
    successDiv.style.zIndex = '2000';
    document.body.appendChild(successDiv);
    
    setTimeout(() => {
        successDiv.remove();
    }, 3000);
}

// Escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Handle OAuth callback on page load
handleOAuthCallback();

