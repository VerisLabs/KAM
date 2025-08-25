// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item "><a href="index.html">Home</a></li><li class="chapter-item affix "><li class="part-title">src</li><li class="chapter-item "><a href="src/abstracts/index.html">❱ abstracts</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/abstracts/Extsload.sol/abstract.Extsload.html">Extsload</a></li><li class="chapter-item "><a href="src/abstracts/Proxy.sol/abstract.Proxy.html">Proxy</a></li></ol></li><li class="chapter-item "><a href="src/adapters/index.html">❱ adapters</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/adapters/BaseAdapter.sol/contract.BaseAdapter.html">BaseAdapter</a></li><li class="chapter-item "><a href="src/adapters/CustodialAdapter.sol/contract.CustodialAdapter.html">CustodialAdapter</a></li></ol></li><li class="chapter-item "><a href="src/base/index.html">❱ base</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/base/MultiFacetProxy.sol/contract.MultiFacetProxy.html">MultiFacetProxy</a></li><li class="chapter-item "><a href="src/base/kBase.sol/contract.kBase.html">kBase</a></li></ol></li><li class="chapter-item "><a href="src/interfaces/index.html">❱ interfaces</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/interfaces/modules/index.html">❱ modules</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/interfaces/modules/IVaultBatch.sol/interface.IVaultBatch.html">IVaultBatch</a></li><li class="chapter-item "><a href="src/interfaces/modules/IVaultClaim.sol/interface.IVaultClaim.html">IVaultClaim</a></li><li class="chapter-item "><a href="src/interfaces/modules/IVaultFees.sol/interface.IVaultFees.html">IVaultFees</a></li></ol></li><li class="chapter-item "><a href="src/interfaces/IAdapter.sol/interface.IAdapter.html">IAdapter</a></li><li class="chapter-item "><a href="src/interfaces/IExtsload.sol/interface.IExtsload.html">IExtsload</a></li><li class="chapter-item "><a href="src/interfaces/IkAssetRouter.sol/interface.IkAssetRouter.html">IkAssetRouter</a></li><li class="chapter-item "><a href="src/interfaces/IkBatchReceiver.sol/interface.IkBatchReceiver.html">IkBatchReceiver</a></li><li class="chapter-item "><a href="src/interfaces/IkMinter.sol/interface.IkMinter.html">IkMinter</a></li><li class="chapter-item "><a href="src/interfaces/IkRegistry.sol/interface.IkRegistry.html">IkRegistry</a></li><li class="chapter-item "><a href="src/interfaces/IkStakingVault.sol/interface.IkStakingVault.html">IkStakingVault</a></li><li class="chapter-item "><a href="src/interfaces/IkToken.sol/interface.IkToken.html">IkToken</a></li></ol></li><li class="chapter-item "><a href="src/kStakingVault/index.html">❱ kStakingVault</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/kStakingVault/base/index.html">❱ base</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/kStakingVault/base/BaseVaultModule.sol/interface.IFeesModule.html">IFeesModule</a></li><li class="chapter-item "><a href="src/kStakingVault/base/BaseVaultModule.sol/abstract.BaseVaultModule.html">BaseVaultModule</a></li></ol></li><li class="chapter-item "><a href="src/kStakingVault/modules/index.html">❱ modules</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/kStakingVault/modules/BatchModule.sol/contract.BatchModule.html">BatchModule</a></li><li class="chapter-item "><a href="src/kStakingVault/modules/ClaimModule.sol/contract.ClaimModule.html">ClaimModule</a></li><li class="chapter-item "><a href="src/kStakingVault/modules/FeesModule.sol/contract.FeesModule.html">FeesModule</a></li></ol></li><li class="chapter-item "><a href="src/kStakingVault/types/index.html">❱ types</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/kStakingVault/types/BaseVaultModuleTypes.sol/library.BaseVaultModuleTypes.html">BaseVaultModuleTypes</a></li></ol></li><li class="chapter-item "><a href="src/kStakingVault/kStakingVault.sol/contract.kStakingVault.html">kStakingVault</a></li></ol></li><li class="chapter-item "><a href="src/kAssetRouter.sol/contract.kAssetRouter.html">kAssetRouter</a></li><li class="chapter-item "><a href="src/kBatchReceiver.sol/contract.kBatchReceiver.html">kBatchReceiver</a></li><li class="chapter-item "><a href="src/kMinter.sol/contract.kMinter.html">kMinter</a></li><li class="chapter-item "><a href="src/kRegistry.sol/contract.kRegistry.html">kRegistry</a></li><li class="chapter-item "><a href="src/kToken.sol/contract.kToken.html">kToken</a></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
