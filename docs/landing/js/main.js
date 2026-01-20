/**
 * CodeVoyager Landing Page JavaScript
 *
 * Features:
 * - Fetch latest release from GitHub API
 * - Scroll-triggered animations
 * - Smooth interactions
 */

(function () {
    'use strict';

    // ==========================================================================
    // Configuration
    // ==========================================================================

    const CONFIG = {
        github: {
            owner: 'penkzhou',
            repo: 'CodeVoyager',
            apiUrl: 'https://api.github.com/repos/penkzhou/CodeVoyager/releases/latest'
        },
        animation: {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        }
    };

    // ==========================================================================
    // GitHub Release Fetcher
    // ==========================================================================

    class ReleaseFetcher {
        constructor() {
            this.downloadButtons = document.querySelectorAll('#download-btn, #download-btn-footer');
            this.versionElements = document.querySelectorAll('#download-version, #download-version-footer');
            this.release = null;
        }

        async init() {
            try {
                await this.fetchLatestRelease();
                this.updateUI();
            } catch (error) {
                console.error('Failed to fetch release:', error);
                this.showFallback();
            }
        }

        async fetchLatestRelease() {
            const response = await fetch(CONFIG.github.apiUrl, {
                headers: {
                    'Accept': 'application/vnd.github.v3+json'
                }
            });

            if (!response.ok) {
                throw new Error(`GitHub API error: ${response.status}`);
            }

            this.release = await response.json();
        }

        updateUI() {
            if (!this.release) return;

            const version = this.release.tag_name;
            const dmgAsset = this.findDMGAsset();

            // Update version text
            this.versionElements.forEach(el => {
                el.textContent = version;
            });

            // Update download links
            if (dmgAsset) {
                this.downloadButtons.forEach(btn => {
                    btn.href = dmgAsset.browser_download_url;
                    btn.setAttribute('download', '');
                });
            } else {
                // Fallback to releases page
                this.downloadButtons.forEach(btn => {
                    btn.href = this.release.html_url;
                });
            }
        }

        findDMGAsset() {
            if (!this.release || !this.release.assets) return null;

            return this.release.assets.find(asset =>
                asset.name.endsWith('.dmg')
            );
        }

        showFallback() {
            // Link directly to latest release page (not releases list)
            const latestReleaseUrl = `https://github.com/${CONFIG.github.owner}/${CONFIG.github.repo}/releases/latest`;

            this.versionElements.forEach(el => {
                el.textContent = 'Latest';
            });

            this.downloadButtons.forEach(btn => {
                btn.href = latestReleaseUrl;
            });
        }
    }

    // ==========================================================================
    // Scroll Animations
    // ==========================================================================

    class ScrollAnimator {
        constructor() {
            this.observer = null;
        }

        init() {
            if (!('IntersectionObserver' in window)) {
                this.showAllElements();
                return;
            }

            this.createObserver();
            this.observeElements();
        }

        createObserver() {
            this.observer = new IntersectionObserver(
                (entries) => this.handleIntersection(entries),
                {
                    threshold: CONFIG.animation.threshold,
                    rootMargin: CONFIG.animation.rootMargin
                }
            );
        }

        handleIntersection(entries) {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('visible');
                    this.observer.unobserve(entry.target);
                }
            });
        }

        observeElements() {
            // Observe fade-in elements
            document.querySelectorAll('.fade-in').forEach(el => {
                this.observer.observe(el);
            });

            // Observe stagger-children containers
            document.querySelectorAll('.stagger-children').forEach(el => {
                this.observer.observe(el);
            });
        }

        showAllElements() {
            document.querySelectorAll('.fade-in, .stagger-children').forEach(el => {
                el.classList.add('visible');
            });
        }
    }

    // ==========================================================================
    // Navigation Enhancements
    // ==========================================================================

    class Navigation {
        constructor() {
            this.nav = document.querySelector('.nav');
            this.lastScrollY = 0;
        }

        init() {
            this.setupScrollBehavior();
            this.setupSmoothScroll();
        }

        setupScrollBehavior() {
            let ticking = false;

            window.addEventListener('scroll', () => {
                if (!ticking) {
                    window.requestAnimationFrame(() => {
                        this.handleScroll();
                        ticking = false;
                    });
                    ticking = true;
                }
            });
        }

        handleScroll() {
            const currentScrollY = window.scrollY;

            // Add/remove scrolled class for nav styling
            if (currentScrollY > 50) {
                this.nav.classList.add('scrolled');
            } else {
                this.nav.classList.remove('scrolled');
            }

            this.lastScrollY = currentScrollY;
        }

        setupSmoothScroll() {
            document.querySelectorAll('a[href^="#"]').forEach(anchor => {
                anchor.addEventListener('click', (e) => {
                    const targetId = anchor.getAttribute('href');
                    if (targetId === '#') return;

                    const target = document.querySelector(targetId);
                    if (target) {
                        e.preventDefault();
                        target.scrollIntoView({
                            behavior: 'smooth',
                            block: 'start'
                        });
                    }
                });
            });
        }
    }

    // ==========================================================================
    // Performance Bar Animation
    // ==========================================================================

    class PerformanceBars {
        constructor() {
            this.bars = document.querySelectorAll('.bar-fill');
            this.observed = false;
        }

        init() {
            if (!('IntersectionObserver' in window)) {
                this.animateBars();
                return;
            }

            const observer = new IntersectionObserver(
                (entries) => {
                    entries.forEach(entry => {
                        if (entry.isIntersecting && !this.observed) {
                            this.observed = true;
                            this.animateBars();
                        }
                    });
                },
                { threshold: 0.5 }
            );

            const comparison = document.querySelector('.comparison');
            if (comparison) {
                observer.observe(comparison);
            }
        }

        animateBars() {
            this.bars.forEach(bar => {
                const width = bar.style.getPropertyValue('--width');
                bar.style.width = '0';
                requestAnimationFrame(() => {
                    bar.style.width = width;
                });
            });
        }
    }

    // ==========================================================================
    // Initialize Everything
    // ==========================================================================

    function init() {
        // Add animation classes to elements
        addAnimationClasses();

        // Initialize components
        const releaseFetcher = new ReleaseFetcher();
        const scrollAnimator = new ScrollAnimator();
        const navigation = new Navigation();
        const performanceBars = new PerformanceBars();

        releaseFetcher.init();
        scrollAnimator.init();
        navigation.init();
        performanceBars.init();
    }

    function addAnimationClasses() {
        // Add fade-in to section headers
        document.querySelectorAll('.section-header').forEach(el => {
            el.classList.add('fade-in');
        });

        // Add stagger-children to grids
        document.querySelectorAll('.features-grid, .stats-grid, .install-steps').forEach(el => {
            el.classList.add('stagger-children');
        });

        // Add fade-in to other elements
        document.querySelectorAll('.comparison, .install-note, .install-cta').forEach(el => {
            el.classList.add('fade-in');
        });
    }

    // Run when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
