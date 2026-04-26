// Initialize Lucide icons
lucide.createIcons();

// Scroll Animations
document.addEventListener('DOMContentLoaded', () => {
    // Navbar effect on scroll
    const navbar = document.querySelector('.navbar');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            navbar.style.background = 'rgba(250, 249, 241, 0.95)';
            navbar.style.boxShadow = '0 2px 10px rgba(0,0,0,0.05)';
        } else {
            navbar.style.background = 'rgba(250, 249, 241, 0.8)';
            navbar.style.boxShadow = 'none';
        }
    });

    // Intersection Observer for scroll animations
    const observerOptions = {
        threshold: 0.1,
        rootMargin: "0px 0px -50px 0px"
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                
                // Handle staggered animations for grids
                if (entry.target.classList.contains('icon-grid') || entry.target.classList.contains('color-logic-grid') || entry.target.classList.contains('three-step-grid') || entry.target.classList.contains('two-column-mockup')) {
                    const children = entry.target.querySelectorAll('.stagger-in');
                    children.forEach((child, index) => {
                        setTimeout(() => {
                            child.classList.add('visible');
                        }, index * 150); // 150ms stagger
                    });
                }
            }
        });
    }, observerOptions);

    // Observe standalone animated elements
    document.querySelectorAll('.fade-up, .fade-left').forEach(el => {
        observer.observe(el);
    });

    // Observe containers for staggered animations
    document.querySelectorAll('.icon-grid, .color-logic-grid, .three-step-grid, .two-column-mockup').forEach(el => {
        observer.observe(el);
    });

    // Handle Image Error (fallback for Logo)
    const logoImg = document.getElementById('brand-logo');
    if (logoImg) {
        logoImg.addEventListener('error', function() {
            this.style.display = 'none';
            const fallbackText = this.nextElementSibling;
            if (fallbackText) {
                fallbackText.style.display = 'block';
            }
        });
    }
});
