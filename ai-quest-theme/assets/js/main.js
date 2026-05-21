// Neural Network Background Animation
const canvas = document.getElementById('neural-canvas');
if (canvas) {
    const ctx = canvas.getContext('2d');

    let particles = [];
    let mouse = { x: null, y: null };

    function resize() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }

    window.addEventListener('resize', resize);
    window.addEventListener('mousemove', (e) => {
        mouse.x = e.x;
        mouse.y = e.y;
    });

    class Particle {
        constructor() {
            this.x = Math.random() * canvas.width;
            this.y = Math.random() * canvas.height;
            this.size = Math.random() * 2 + 1;
            this.speedX = Math.random() * 0.5 - 0.25;
            this.speedY = Math.random() * 0.5 - 0.25;
        }

        update() {
            this.x += this.speedX;
            this.y += this.speedY;

            if (this.x > canvas.width) this.x = 0;
            if (this.x < 0) this.x = canvas.width;
            if (this.y > canvas.height) this.y = 0;
            if (this.y < 0) this.y = canvas.height;
        }

        draw() {
            ctx.fillStyle = '#00f0ff';
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    function init() {
        particles = [];
        resize();
        for (let i = 0; i < 80; i++) {
            particles.push(new Particle());
        }
    }

    function animate() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        for (let i = 0; i < particles.length; i++) {
            particles[i].update();
            particles[i].draw();

            for (let j = i; j < particles.length; j++) {
                const dx = particles[i].x - particles[j].x;
                const dy = particles[i].y - particles[j].y;
                const distance = Math.sqrt(dx * dx + dy * dy);

                if (distance < 150) {
                    ctx.strokeStyle = `rgba(0, 240, 255, ${1 - distance / 150})`;
                    ctx.lineWidth = 0.5;
                    ctx.beginPath();
                    ctx.moveTo(particles[i].x, particles[i].y);
                    ctx.lineTo(particles[j].x, particles[j].y);
                    ctx.stroke();
                }
            }
        }
        requestAnimationFrame(animate);
    }

    init();
    animate();
}

// Reveal Logic (Intersection Observer)
if ('IntersectionObserver' in window) {
    const observerOptions = {
        threshold: 0.15,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('active');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    document.querySelectorAll('.reveal-on-scroll, .glass-card, #services, #cases').forEach(el => {
        el.classList.add('reveal-on-scroll');
        observer.observe(el);
    });
} else {
    document.querySelectorAll('.reveal-on-scroll, .glass-card, #services, #cases').forEach(el => {
        el.classList.add('active');
    });
}

// Consultation Popup Logic
document.addEventListener('DOMContentLoaded', () => {
    const popup = document.getElementById('consult-popup');
    const closeBtn = document.getElementById('close-consult-popup');
    const consultForm = document.getElementById('consult-form');
    const openBtns = document.querySelectorAll('[data-open-consult-popup]');

    const header = document.getElementById('header');
    const miniHeader = document.getElementById('mini-header');
    const backToTop = document.getElementById('back-to-top');
    const backToTopThreshold = 20;
    let miniHeaderThreshold = 300;

    const updateMiniHeaderThreshold = () => {
        if (!header) return;
        miniHeaderThreshold = Math.max(80, Math.ceil(header.getBoundingClientRect().height));
    };

    const updateHeaderAndBackToTop = () => {
        const scrolled = window.scrollY > backToTopThreshold;
        const pastHeader = window.scrollY > miniHeaderThreshold;
        if (miniHeader) {
            miniHeader.classList.toggle('is-visible', pastHeader);
            miniHeader.setAttribute('aria-hidden', pastHeader ? 'false' : 'true');
        }
        if (backToTop) {
            backToTop.classList.toggle('is-visible', scrolled);
        }
    };

    let isTicking = false;
    const onScroll = () => {
        if (isTicking) return;
        isTicking = true;
        window.requestAnimationFrame(() => {
            updateHeaderAndBackToTop();
            isTicking = false;
        });
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', () => {
        updateMiniHeaderThreshold();
        updateHeaderAndBackToTop();
    });
    updateMiniHeaderThreshold();
    updateHeaderAndBackToTop();
    // Re-measure sau khi trang load xong (font, ảnh đã render)
    window.addEventListener('load', () => {
        updateMiniHeaderThreshold();
        updateHeaderAndBackToTop();
    });

    if (backToTop) {
        backToTop.addEventListener('click', (e) => {
            e.preventDefault();
            window.scrollTo({ top: 0, behavior: 'smooth' });
        });
    }

    const topbarLocation = document.querySelector('.topbar-location');
    if (topbarLocation) {
        const trigger = topbarLocation.querySelector('.topbar-location-trigger');
        const closeDelayMs = 180;
        let closeTimeoutId = null;

        const openMenu = () => {
            if (closeTimeoutId) {
                clearTimeout(closeTimeoutId);
                closeTimeoutId = null;
            }
            topbarLocation.classList.add('is-open');
        };

        const closeMenu = () => {
            if (closeTimeoutId) {
                clearTimeout(closeTimeoutId);
            }
            closeTimeoutId = setTimeout(() => {
                topbarLocation.classList.remove('is-open');
            }, closeDelayMs);
        };

        topbarLocation.addEventListener('mouseenter', openMenu);
        topbarLocation.addEventListener('mouseleave', closeMenu);
        topbarLocation.addEventListener('focusin', openMenu);
        topbarLocation.addEventListener('focusout', closeMenu);

        if (trigger) {
            trigger.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                if (topbarLocation.classList.contains('is-open')) {
                    topbarLocation.classList.remove('is-open');
                } else {
                    openMenu();
                }
            });
        }

        document.addEventListener('click', (e) => {
            if (!topbarLocation.contains(e.target)) {
                topbarLocation.classList.remove('is-open');
            }
        });

        const menu = topbarLocation.querySelector('.topbar-location-menu');
        if (menu) {
            menu.addEventListener('click', (e) => {
                const target = e.target;
                if (!(target instanceof Element)) return;
                const item = target.closest('.topbar-location-item');
                if (!item) return;

                e.preventDefault();
                e.stopPropagation();
                const href = item.getAttribute('href');
                if (href) {
                    window.open(href, '_blank');
                }
            });
        }
    }

    if (popup && closeBtn) {
        // Function to open popup
        const openPopup = () => {
            popup.style.display = 'flex';
            document.body.style.overflow = 'hidden'; // Prevent scrolling
        };

        // Function to close popup
        const closePopup = () => {
            popup.style.display = 'none';
            document.body.style.overflow = ''; // Restore scrolling
        };

        // Open on button click
        openBtns.forEach((btn) => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                openPopup();
            });
        });

        // Close on X click
        closeBtn.addEventListener('click', closePopup);

        // Close on clicking outside the modal content
        popup.addEventListener('click', (e) => {
            if (e.target === popup) {
                closePopup();
            }
        });

        // Tự động hiện popup sau 3 giây (chỉ 1 lần mỗi session)
        if (!sessionStorage.getItem('consult_popup_shown')) {
            setTimeout(() => {
                openPopup();
                sessionStorage.setItem('consult_popup_shown', '1');
            }, 3000);
        }

    }

    // Handle form submission
    if (consultForm) {
        consultForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const formData = new FormData(consultForm);
            const btn = consultForm.querySelector('[type="submit"]');
            const cfg = window.aiqConfig || {};

            if (btn) { btn.disabled = true; btn.textContent = 'Đang gửi...'; }

            const payload = {
                lead_type:    'consultation',
                full_name:    formData.get('full_name'),
                phone:        formData.get('phone'),
                service_type: formData.get('service'),
                note:         formData.get('note') || '',
                source:       'website',
                status:       'new'
            };
            if (cfg.storeId) payload.store_id = cfg.storeId;

            fetch((cfg.supabaseUrl || '') + '/rest/v1/website_leads', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'apikey': cfg.supabaseKey || '',
                    'Authorization': 'Bearer ' + (cfg.supabaseKey || ''),
                    'Prefer': 'return=minimal'
                },
                body: JSON.stringify(payload)
            })
            .then(res => {
                if (res.ok || res.status === 201) {
                    alert('Cảm ơn ' + (formData.get('full_name') || '') + '! Yêu cầu tư vấn đã được gửi. Chúng tôi sẽ liên hệ sớm nhất.');
                    consultForm.reset();
                    if (popup) { popup.style.display = 'none'; document.body.style.overflow = ''; }
                } else {
                    alert('Có lỗi xảy ra. Vui lòng thử lại hoặc liên hệ hotline.');
                }
            })
            .catch(() => alert('Có lỗi xảy ra. Vui lòng thử lại.'))
            .finally(() => {
                if (btn) { btn.disabled = false; btn.textContent = 'Gửi yêu cầu'; }
            });
        });
    }

    // Service Detail Modal Logic
    const serviceCards = document.querySelectorAll('.service-card');
    const serviceModal = document.getElementById('service-modal');
    const closeServiceModal = document.getElementById('close-service-modal');

    if (serviceModal && closeServiceModal) {
        serviceCards.forEach(card => {
            card.addEventListener('click', (e) => {
                // Get data from the hidden script tag
                const dataScript = card.querySelector('.service-full-data');
                if (!dataScript) return;

                try {
                    const data = JSON.parse(dataScript.textContent);
                    
                    // Populate modal fields
                    document.getElementById('service-modal-title').textContent = data.name;
                    document.getElementById('service-modal-img').src = data.image_url;
                    document.getElementById('service-modal-img').alt = data.image_alt || data.name;
                    document.getElementById('service-modal-price').textContent = data.price;
                    document.getElementById('service-modal-time').textContent = data.weight;
                    document.getElementById('service-modal-desc-content').textContent = data.description || 'Đang cập nhật nội dung chi tiết cho dịch vụ này...';
                    const bookingLink = document.getElementById('service-modal-booking');
                    if (bookingLink) {
                        bookingLink.href = data.booking_url || '#';
                    }
                    
                    // Show modal
                    serviceModal.style.display = 'flex';
                    document.body.style.overflow = 'hidden';
                } catch (err) {
                    console.error('Error parsing service data:', err);
                }
            });
        });

        // Close service modal
        closeServiceModal.addEventListener('click', () => {
            serviceModal.style.display = 'none';
            document.body.style.overflow = '';
        });

        // Close on outside click
        serviceModal.addEventListener('click', (e) => {
            if (e.target === serviceModal) {
                serviceModal.style.display = 'none';
                document.body.style.overflow = '';
            }
        });
    }

    // Service Slider Logic
    const slider = document.getElementById('service-slider');
    const prevBtn = document.getElementById('service-prev');
    const nextBtn = document.getElementById('service-next');
    
    if (slider && prevBtn && nextBtn) {
        let currentIndex = 0;
        const items = slider.querySelectorAll('.service-card');
        const totalItems = items.length;
        if (totalItems === 0) {
            prevBtn.style.display = 'none';
            nextBtn.style.display = 'none';
            return;
        }

        const updateSlider = () => {
            const containerWidth = slider.parentElement.offsetWidth;
            const itemWidth = items[0].offsetWidth;
            // Đọc gap thực tế từ CSS thay vì hardcode
            const computedGap = parseFloat(window.getComputedStyle(slider).gap) || 0;
            
            // Calculate how many items are visible
            let visibleItems = 3;
            if (window.innerWidth <= 768) visibleItems = 1;
            else if (window.innerWidth <= 991) visibleItems = 2;

            // Limit currentIndex
            const maxIndex = Math.max(0, totalItems - visibleItems);
            if (currentIndex > maxIndex) currentIndex = maxIndex;
            if (currentIndex < 0) currentIndex = 0;

            // Calculate translation dựa trên itemWidth thực tế
            const moveX = currentIndex * (itemWidth + computedGap);
            slider.style.transform = `translateX(-${moveX}px)`;

            // Update button visibility if needed (optional)
            prevBtn.style.display = currentIndex === 0 ? 'none' : 'flex';
            nextBtn.style.display = currentIndex >= maxIndex ? 'none' : 'flex';
        };

        nextBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            currentIndex++;
            updateSlider();
        });

        prevBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            currentIndex--;
            updateSlider();
        });

        // Initialize and handle resize
        updateSlider();
        window.addEventListener('resize', updateSlider);
    }

    const carousels = document.querySelectorAll('[data-carousel]');
    carousels.forEach((carousel) => {
        const track = carousel.querySelector('[data-carousel-track]');
        const prev = carousel.querySelector('[data-carousel-prev]');
        const next = carousel.querySelector('[data-carousel-next]');
        const dotsWrap = carousel.parentElement ? carousel.parentElement.querySelector('[data-carousel-dots]') : null;
        if (!track || !prev || !next) return;

        const slides = Array.from(track.children);
        const total = slides.length;
        if (total <= 1) {
            prev.style.display = 'none';
            next.style.display = 'none';
            return;
        }

        let index = 0;

        const setActiveDot = () => {
            if (!dotsWrap) return;
            const dots = Array.from(dotsWrap.querySelectorAll('[data-carousel-dot]'));
            dots.forEach((d) => d.classList.remove('is-active'));
            const active = dots.find((d) => Number.parseInt(d.getAttribute('data-carousel-dot') || '-1', 10) === index);
            if (active) active.classList.add('is-active');
        };

        const update = () => {
            track.style.transform = `translateX(-${index * 100}%)`;
            setActiveDot();
        };

        prev.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            index = (index - 1 + total) % total;
            update();
        });

        next.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            index = (index + 1) % total;
            update();
        });

        if (dotsWrap) {
            dotsWrap.addEventListener('click', (e) => {
                const target = e.target;
                if (!(target instanceof Element)) return;
                const dot = target.closest('[data-carousel-dot]');
                if (!dot) return;
                e.preventDefault();
                const idx = Number.parseInt(dot.getAttribute('data-carousel-dot') || '0', 10);
                if (!Number.isFinite(idx)) return;
                index = Math.max(0, Math.min(total - 1, idx));
                update();
            });
        }

        update();
    });

    const homeSlider = document.querySelector('[data-home-slider]');
    if (homeSlider) {
        if (homeSlider.getAttribute('data-slider-initialized') === '1') {
            return;
        }
        homeSlider.setAttribute('data-slider-initialized', '1');

        const viewport = homeSlider.querySelector('[data-home-slider-viewport]') || homeSlider;
        const track = homeSlider.querySelector('[data-home-slider-track]');
        const prev = homeSlider.querySelector('[data-home-slider-prev]');
        const next = homeSlider.querySelector('[data-home-slider-next]');
        if (track && prev && next) {
            Array.from(track.querySelectorAll('[data-home-slider-clone]')).forEach((clone) => clone.remove());

            const realSlides = Array.from(track.children).filter((el) => {
                if (!(el instanceof HTMLElement)) return false;
                const img = el.querySelector('img');
                if (!img) return true;
                const src = (img.getAttribute('src') || '').trim();
                return src !== '';
            });
            const realTotal = realSlides.length;
            if (realTotal <= 1) {
                prev.style.display = 'none';
                next.style.display = 'none';
            } else {
                const intervalSeconds = Number.parseFloat(homeSlider.getAttribute('data-interval-seconds') || '5');
                const intervalMs = Math.max(1000, Math.min(60000, Math.round((Number.isFinite(intervalSeconds) ? intervalSeconds : 5) * 1000)));

                let realIndex = Number.parseInt(homeSlider.getAttribute('data-initial-index') || '0', 10);
                if (!Number.isFinite(realIndex)) realIndex = 0;
                realIndex = Math.max(0, Math.min(realTotal - 1, realIndex));

                const firstClone = realSlides[0].cloneNode(true);
                const lastClone = realSlides[realTotal - 1].cloneNode(true);
                firstClone.setAttribute('data-home-slider-clone', '1');
                lastClone.setAttribute('data-home-slider-clone', '1');
                track.insertBefore(lastClone, realSlides[0]);
                track.appendChild(firstClone);

                const slides = Array.from(track.children);
                const total = slides.length;
                let position = realIndex + 1;

                let width = 0;
                let autoTimer = null;
                let isDragging = false;
                let isTransitioning = false;
                let transitionTimeoutId = null;
                let startX = 0;
                let startTranslate = 0;
                let lastDelta = 0;

                const measure = () => {
                    width = Math.max(1, viewport.getBoundingClientRect().width);
                };

                const setTransform = (x, withTransition) => {
                    track.style.transition = withTransition ? 'transform 420ms ease' : 'none';
                    track.style.transform = `translateX(${x}px)`;
                };

                const dotsWrap = homeSlider.querySelector('[data-home-slider-dots]');
                const allDots = dotsWrap ? Array.from(dotsWrap.querySelectorAll('[data-home-slider-dot]')) : [];

                const updateDots = () => {
                    const realPos = ((position - 1) % realTotal + realTotal) % realTotal;
                    allDots.forEach((d, i) => d.classList.toggle('is-active', i === realPos));
                };

                const update = (withTransition = true) => {
                    measure();
                    setTransform(-position * width, withTransition);
                    updateDots();
                };

                const clearTransitionGuard = () => {
                    if (transitionTimeoutId) {
                        window.clearTimeout(transitionTimeoutId);
                        transitionTimeoutId = null;
                    }
                };

                const startTransitionGuard = () => {
                    clearTransitionGuard();
                    transitionTimeoutId = window.setTimeout(() => {
                        isTransitioning = false;
                        transitionTimeoutId = null;
                    }, 520);
                };

                const goNext = () => {
                    if (isTransitioning || isDragging) return;
                    if (position === total - 1) {
                        position = 1;
                        update(false);
                    } else if (position === 0) {
                        position = total - 2;
                        update(false);
                    }
                    const nextPos = Math.min(total - 1, position + 1);
                    if (nextPos === position) return;
                    position = nextPos;
                    isTransitioning = true;
                    startTransitionGuard();
                    update(true);
                };

                const goPrev = () => {
                    if (isTransitioning || isDragging) return;
                    if (position === 0) {
                        position = total - 2;
                        update(false);
                    } else if (position === total - 1) {
                        position = 1;
                        update(false);
                    }
                    const prevPos = Math.max(0, position - 1);
                    if (prevPos === position) return;
                    position = prevPos;
                    isTransitioning = true;
                    startTransitionGuard();
                    update(true);
                };

                const stopAuto = () => {
                    if (autoTimer) {
                        window.clearInterval(autoTimer);
                        autoTimer = null;
                    }
                };

                const startAuto = () => {
                    stopAuto();
                    autoTimer = window.setInterval(() => goNext(), intervalMs);
                };

                prev.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    stopAuto();
                    goPrev();
                    startAuto();
                });

                next.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    stopAuto();
                    goNext();
                    startAuto();
                });

                track.addEventListener('transitionend', (e) => {
                    if (e && e.target !== track) return;
                    if (position === total - 1) {
                        position = 1;
                        update(false);
                    } else if (position === 0) {
                        position = total - 2;
                        update(false);
                    }
                    clearTransitionGuard();
                    isTransitioning = false;
                });

                const getClientX = (evt) => {
                    if (evt && evt.touches && evt.touches.length) return evt.touches[0].clientX;
                    if (evt && evt.changedTouches && evt.changedTouches.length) return evt.changedTouches[0].clientX;
                    return evt.clientX;
                };

                const onDragStart = (e) => {
                    const target = e.target;
                    if (target instanceof Element && target.closest('[data-home-slider-prev], [data-home-slider-next]')) {
                        return;
                    }
                    isDragging = true;
                    stopAuto();
                    if (isTransitioning) {
                        clearTransitionGuard();
                        isTransitioning = false;
                        update(false);
                    }
                    measure();
                    startX = getClientX(e);
                    startTranslate = -position * width;
                    lastDelta = 0;
                    viewport.classList.add('is-dragging');
                    if (e.cancelable) e.preventDefault();
                };

                const onDragMove = (e) => {
                    if (!isDragging) return;
                    lastDelta = getClientX(e) - startX;
                    setTransform(startTranslate + lastDelta, false);
                    if (e.cancelable) e.preventDefault();
                };

                const onDragEnd = (e) => {
                    if (!isDragging) return;
                    isDragging = false;
                    viewport.classList.remove('is-dragging');

                    const threshold = Math.min(140, width * 0.18);
                    if (Math.abs(lastDelta) > threshold) {
                        if (lastDelta < 0) {
                            goNext();
                        } else {
                            goPrev();
                        }
                    } else {
                        isTransitioning = true;
                        startTransitionGuard();
                        update(true);
                    }
                    startAuto();
                };

                const supportsPointer = 'PointerEvent' in window;
                if (supportsPointer) {
                    viewport.addEventListener('pointerdown', onDragStart);
                    viewport.addEventListener('pointermove', onDragMove);
                    viewport.addEventListener('pointerup', onDragEnd);
                    viewport.addEventListener('pointercancel', onDragEnd);
                } else {
                    viewport.addEventListener('mousedown', onDragStart);
                    window.addEventListener('mousemove', onDragMove);
                    window.addEventListener('mouseup', onDragEnd);

                    viewport.addEventListener('touchstart', onDragStart, { passive: false });
                    viewport.addEventListener('touchmove', onDragMove, { passive: false });
                    viewport.addEventListener('touchend', onDragEnd);
                    viewport.addEventListener('touchcancel', onDragEnd);
                }
                window.addEventListener('resize', () => update(false));

                // Dot click
                if (dotsWrap) {
                    dotsWrap.addEventListener('click', (e) => {
                        const dot = e.target.closest('[data-home-slider-dot]');
                        if (!dot) return;
                        const idx = parseInt(dot.getAttribute('data-home-slider-dot') || '0', 10);
                        if (!isFinite(idx)) return;
                        stopAuto();
                        position = idx + 1;
                        isTransitioning = true;
                        startTransitionGuard();
                        update(true);
                        startAuto();
                    });
                }

                update(false);
                startAuto();
            }
        }
    }

    const beforeAfterCarousel = document.querySelector('[data-before-after-carousel]');
    if (beforeAfterCarousel) {
        const viewport = beforeAfterCarousel.querySelector('[data-before-after-viewport]');
        const track = beforeAfterCarousel.querySelector('[data-before-after-track]');
        const prev = beforeAfterCarousel.querySelector('[data-before-after-prev]');
        const next = beforeAfterCarousel.querySelector('[data-before-after-next]');
        const dotsWrap = beforeAfterCarousel.parentElement ? beforeAfterCarousel.parentElement.querySelector('[data-before-after-dots]') : null;

        if (viewport && track && prev && next) {
            const slides = Array.from(track.children);
            const total = slides.length;

            if (total <= 1) {
                prev.style.display = 'none';
                next.style.display = 'none';
            }

            let index = total >= 3 ? 1 : 0;
            let viewportWidth = 0;
            let slideWidth = 0;
            let step = 0;

            const parseGap = () => {
                const styles = window.getComputedStyle(track);
                const gapValue = styles.columnGap || styles.gap || '0px';
                const gap = Number.parseFloat(gapValue) || 0;
                return gap;
            };

            const measure = () => {
                viewportWidth = Math.max(1, viewport.getBoundingClientRect().width);
                // Calculate slide width based on viewport, not actual rendered size
                // This ensures consistent step regardless of scale transforms
                const gap = parseGap();
                
                // Check if mobile (viewport width < 576px)
                const isMobile = window.innerWidth <= 576;
                
                if (isMobile) {
                    // Mobile: 1 slide per view, no gap
                    slideWidth = viewportWidth;
                    step = slideWidth; // No gap on mobile
                } else {
                    // Desktop: 3 slides per view
                    slideWidth = (viewportWidth - (2 * gap)) / 3;
                    step = slideWidth + gap;
                }
            };

            const setTransform = (x, withTransition) => {
                if (withTransition) {
                    track.style.transition = 'transform 0.55s cubic-bezier(0.16, 1, 0.3, 1)';
                } else {
                    track.style.transition = 'none';
                }
                track.style.transform = `translateX(${x}px)`;
                actualPosition = x; // Store the position we just set
            };

            const setActiveDot = () => {
                if (!dotsWrap) return;
                const dots = Array.from(dotsWrap.querySelectorAll('[data-before-after-dot]'));
                dots.forEach((dot) => dot.classList.remove('is-active'));
                const active = dots.find((d) => Number.parseInt(d.getAttribute('data-before-after-dot') || '-1', 10) === index);
                if (active) active.classList.add('is-active');
            };

            const setActiveSlides = () => {
                slides.forEach((slide) => {
                    slide.classList.remove('is-active');
                    slide.classList.remove('is-adjacent');
                });
                const active = slides[index];
                if (active) active.classList.add('is-active');
                const prevSlide = slides[index - 1];
                const nextSlide = slides[index + 1];
                if (prevSlide) prevSlide.classList.add('is-adjacent');
                if (nextSlide) nextSlide.classList.add('is-adjacent');
            };

            const update = (withTransition = true) => {
                if (total === 0) return;
                measure();
                
                const isMobile = window.innerWidth <= 576;
                let x;
                
                if (isMobile) {
                    // Mobile: Simple - just show one slide at a time
                    x = -(index * step);
                } else if (total <= 3) {
                    // Desktop with 3 or fewer slides: align to the left
                    x = 0;
                } else {
                    // Desktop with more than 3 slides: smart positioning
                    const visibleSlides = 3;
                    
                    if (index === 0) {
                        // First slide: align to left
                        x = 0;
                    } else if (index >= total - visibleSlides + 1) {
                        // Last few slides: align so the last slide is at position 3
                        x = -((total - visibleSlides) * step);
                    } else {
                        // Middle slides: center the active slide in position 2
                        const viewportCenter = viewportWidth / 2;
                        const slideCenter = slideWidth / 2;
                        const centerOffset = viewportCenter - slideCenter;
                        x = -(index * step) + centerOffset;
                    }
                }
                
                setTransform(x, withTransition);
                setActiveDot();
                setActiveSlides();
                
                // Show/hide navigation buttons based on position
                if (index === 0) {
                    prev.style.opacity = '0';
                    prev.style.visibility = 'hidden';
                    prev.style.pointerEvents = 'none';
                } else {
                    prev.style.opacity = '';
                    prev.style.visibility = '';
                    prev.style.pointerEvents = '';
                }
                
                if (index === total - 1) {
                    next.style.opacity = '0';
                    next.style.visibility = 'hidden';
                    next.style.pointerEvents = 'none';
                } else {
                    next.style.opacity = '';
                    next.style.visibility = '';
                    next.style.pointerEvents = '';
                }
            };

            const go = (nextIndex) => {
                index = Math.max(0, Math.min(total - 1, nextIndex));
                update(true);
            };

            prev.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                go(index - 1);
            });

            next.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                go(index + 1);
            });

            if (dotsWrap) {
                dotsWrap.addEventListener('click', (e) => {
                    const target = e.target;
                    if (!(target instanceof Element)) return;
                    const dot = target.closest('[data-before-after-dot]');
                    if (!dot) return;
                    e.preventDefault();
                    const idx = Number.parseInt(dot.getAttribute('data-before-after-dot') || '0', 10);
                    if (Number.isFinite(idx)) go(idx);
                });
            }

            let isDragging = false;
            let dragStarted = false;
            let startX = 0;
            let startTranslate = 0;
            let currentTranslate = 0;
            let startTime = 0;
            let actualPosition = 0; // Store the actual position instead of reading from DOM

            const getTranslateX = () => {
                // Return stored position instead of reading from computed style
                return actualPosition;
            };

            const getClientX = (evt) => {
                if (evt && evt.touches && evt.touches.length) return evt.touches[0].clientX;
                if (evt && evt.changedTouches && evt.changedTouches.length) return evt.changedTouches[0].clientX;
                return evt.clientX;
            };

            const onStart = (e) => {
                if (total <= 1) return;
                
                // Stop any ongoing transition immediately
                track.style.transition = 'none';
                
                isDragging = true;
                dragStarted = false;
                startTime = Date.now();
                measure();
                startX = getClientX(e);
                
                // Use stored position instead of reading from DOM
                startTranslate = actualPosition;
                currentTranslate = startTranslate;
            };

            const onMove = (e) => {
                if (!isDragging) return;
                const delta = getClientX(e) - startX;
                
                if (!dragStarted && Math.abs(delta) > 10) {
                    dragStarted = true;
                    viewport.classList.add('is-dragging');
                }
                
                if (dragStarted) {
                    currentTranslate = startTranslate + delta;
                    setTransform(currentTranslate, false);
                    if (e.cancelable) e.preventDefault();
                }
            };

            const onEnd = () => {
                if (!isDragging) return;
                isDragging = false;
                viewport.classList.remove('is-dragging');

                if (dragStarted) {
                    // Snap to nearest slide
                    // Calculate which slide is closest to center
                    const viewportCenter = viewportWidth / 2;
                    const slideCenter = slideWidth / 2;
                    const centerOffset = viewportCenter - slideCenter;
                    const raw = (centerOffset - currentTranslate) / Math.max(1, step);
                    const nearest = Math.round(raw);
                    go(nearest);
                } else {
                    // Just a click - keep position
                }
                
                dragStarted = false;
            };

            const supportsPointer = 'PointerEvent' in window;
            if (supportsPointer) {
                viewport.addEventListener('pointerdown', onStart);
                window.addEventListener('pointermove', onMove);
                window.addEventListener('pointerup', onEnd);
                window.addEventListener('pointercancel', onEnd);
            } else {
                viewport.addEventListener('mousedown', onStart);
                window.addEventListener('mousemove', onMove);
                window.addEventListener('mouseup', onEnd);

                viewport.addEventListener('touchstart', onStart, { passive: false });
                viewport.addEventListener('touchmove', onMove, { passive: false });
                viewport.addEventListener('touchend', onEnd);
                viewport.addEventListener('touchcancel', onEnd);
            }

            window.addEventListener('resize', () => update(false));
            update(false); // Initialize carousel position
        }
    }

    // Image Lightbox for Before/After
    const createImageLightbox = () => {
        const lightbox = document.createElement('div');
        lightbox.className = 'image-lightbox';
        lightbox.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.95);
            z-index: 10000;
            display: none;
            align-items: center;
            justify-content: center;
            padding: 20px;
        `;

        const img = document.createElement('img');
        img.style.cssText = `
            max-width: 90%;
            max-height: 90%;
            object-fit: contain;
            border-radius: 8px;
        `;

        const closeBtn = document.createElement('button');
        closeBtn.innerHTML = '×';
        closeBtn.style.cssText = `
            position: absolute;
            top: 20px;
            right: 20px;
            background: rgba(255, 255, 255, 0.2);
            border: none;
            color: white;
            font-size: 40px;
            width: 50px;
            height: 50px;
            border-radius: 50%;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: background 0.3s;
        `;
        closeBtn.addEventListener('mouseenter', () => {
            closeBtn.style.background = 'rgba(255, 255, 255, 0.3)';
        });
        closeBtn.addEventListener('mouseleave', () => {
            closeBtn.style.background = 'rgba(255, 255, 255, 0.2)';
        });

        lightbox.appendChild(img);
        lightbox.appendChild(closeBtn);
        document.body.appendChild(lightbox);

        const openLightbox = (src, alt) => {
            img.src = src;
            img.alt = alt || '';
            lightbox.style.display = 'flex';
            document.body.style.overflow = 'hidden';
        };

        const closeLightbox = () => {
            lightbox.style.display = 'none';
            document.body.style.overflow = '';
        };

        closeBtn.addEventListener('click', closeLightbox);
        lightbox.addEventListener('click', (e) => {
            if (e.target === lightbox) {
                closeLightbox();
            }
        });

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && lightbox.style.display === 'flex') {
                closeLightbox();
            }
        });

        return { openLightbox, closeLightbox };
    };

    // Initialize lightbox
    const lightbox = createImageLightbox();

    // Add click handlers to before/after images
    const beforeAfterImages = document.querySelectorAll('[data-before-after-carousel] img');
    const beforeAfterViewport = document.querySelector('[data-before-after-viewport]');
    
    beforeAfterImages.forEach((img) => {
        img.style.cursor = 'pointer';
        img.setAttribute('title', 'Click để xem phóng to');
        
        let clickStartTime = 0;
        let clickStartX = 0;
        let clickStartY = 0;
        
        const handleStart = (e) => {
            clickStartTime = Date.now();
            if (e.type === 'touchstart' && e.touches && e.touches.length > 0) {
                clickStartX = e.touches[0].clientX;
                clickStartY = e.touches[0].clientY;
            } else {
                clickStartX = e.clientX || 0;
                clickStartY = e.clientY || 0;
            }
        };
        
        const handleEnd = (e) => {
            // Don't open if viewport is dragging
            if (beforeAfterViewport && beforeAfterViewport.classList.contains('is-dragging')) {
                return;
            }
            
            // Get end position
            let endX, endY;
            if (e.type === 'touchend' && e.changedTouches && e.changedTouches.length > 0) {
                endX = e.changedTouches[0].clientX;
                endY = e.changedTouches[0].clientY;
            } else {
                endX = e.clientX || clickStartX;
                endY = e.clientY || clickStartY;
            }
            
            // Check if this was a quick tap/click (not a drag/swipe)
            const clickDuration = Date.now() - clickStartTime;
            const moveX = Math.abs(endX - clickStartX);
            const moveY = Math.abs(endY - clickStartY);
            const totalMove = Math.sqrt(moveX * moveX + moveY * moveY);
            
            // Open lightbox if: duration < 400ms AND movement < 5px
            if (clickDuration < 400 && totalMove < 5) {
                e.preventDefault();
                e.stopPropagation();
                const src = img.src;
                const alt = img.alt || 'Before/After Image';
                lightbox.openLightbox(src, alt);
            }
        };
        
        img.addEventListener('mousedown', handleStart);
        img.addEventListener('touchstart', handleStart, { passive: true });
        
        img.addEventListener('click', handleEnd);
        img.addEventListener('touchend', handleEnd);
    });

    // Debug Sticky Bar Clicks
    const stickyItems = document.querySelectorAll('.contact-item');
    stickyItems.forEach(item => {
        item.addEventListener('click', () => {
            console.log('Sticky item clicked:', item.className);
        });
    });
});

document.querySelectorAll('.faq-item').forEach(item => {
    item.querySelector('.faq-question').addEventListener('click', () => {
        item.classList.toggle('active');
        
        // Close other items
        document.querySelectorAll('.faq-item').forEach(otherItem => {
            if (otherItem !== item) {
                otherItem.classList.remove('active');
            }
        });
    });
});

// ---- Mobile Menu ----
(function () {
    var btn = document.getElementById('mobile-menu-btn');
    var drawer = document.getElementById('mobile-nav-drawer');
    var overlay = document.getElementById('mobile-nav-overlay');
    var closeBtn = document.getElementById('mobile-nav-close');

    if (!btn || !drawer) return;

    function openMenu() {
        drawer.classList.add('is-open');
        overlay.classList.add('is-open');
        btn.setAttribute('aria-expanded', 'true');
        document.body.style.overflow = 'hidden';
    }

    function closeMenu() {
        drawer.classList.remove('is-open');
        overlay.classList.remove('is-open');
        btn.setAttribute('aria-expanded', 'false');
        document.body.style.overflow = '';
    }

    btn.addEventListener('click', openMenu);
    if (closeBtn) closeBtn.addEventListener('click', closeMenu);
    if (overlay) overlay.addEventListener('click', closeMenu);

    // Close on nav link click
    drawer.querySelectorAll('a').forEach(function (a) {
        a.addEventListener('click', closeMenu);
    });
}());



// ============================================
// FACEBOOK REELS - grid + popup + swipe/drag
// Mobile: swipe trái/phải + lên/xuống trong popup
// Desktop: drag chuột + scroll wheel trong popup
// ============================================
(function () {
    console.log('Facebook Reels script starting...');
    
    // Reel grid slider với swipe/drag
    const reelSlider = document.querySelector('.rls-vp');
    const reelTrack = document.querySelector('.rls-tr');
    const reelPrevBtn = document.getElementById('rls-l');
    const reelNextBtn = document.getElementById('rls-r');
    
    console.log('Reel elements found:', { reelSlider, reelTrack, reelPrevBtn, reelNextBtn });
    
    if (reelSlider && reelTrack && reelPrevBtn && reelNextBtn) {
        const reelCards = Array.from(reelTrack.children);
        const totalReels = reelCards.length;
        
        if (totalReels > 0) {
            let currentReelIndex = 0;
            let reelWidth = 0;
            let reelGap = 10;
            let visibleReels = 6; // Desktop default
            let isDraggingReel = false;
            let startXReel = 0;
            let startTranslateReel = 0;
            let currentTranslateReel = 0;
            
            const measureReel = () => {
                const containerWidth = reelSlider.offsetWidth;
                reelWidth = reelCards[0] ? reelCards[0].offsetWidth : 0;
                reelGap = 10;
                
                // Calculate visible items based on screen size
                if (window.innerWidth <= 768) {
                    visibleReels = 3;
                } else if (window.innerWidth <= 991) {
                    visibleReels = 4;
                } else {
                    visibleReels = 6;
                }
            };
            
            const updateReelTransform = (translate, withTransition = true) => {
                reelTrack.style.transition = withTransition ? 'transform 0.4s cubic-bezier(0.16,1,0.3,1)' : 'none';
                reelTrack.style.transform = `translateX(${translate}px)`;
            };
            
            const goToReelIndex = (index, withTransition = true) => {
                measureReel();
                const maxIndex = Math.max(0, totalReels - visibleReels);
                currentReelIndex = Math.max(0, Math.min(maxIndex, index));
                const translateX = -(currentReelIndex * (reelWidth + reelGap));
                updateReelTransform(translateX, withTransition);
                currentTranslateReel = translateX;
            };
            
            const nextReel = () => {
                goToReelIndex(currentReelIndex + 1);
            };
            
            const prevReel = () => {
                goToReelIndex(currentReelIndex - 1);
            };
            
            // Button events
            reelNextBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                nextReel();
            });
            
            reelPrevBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                prevReel();
            });
            
            // Touch/Mouse events for drag
            const getClientX = (e) => {
                if (e.touches && e.touches.length) return e.touches[0].clientX;
                if (e.changedTouches && e.changedTouches.length) return e.changedTouches[0].clientX;
                return e.clientX;
            };
            
            const onReelDragStart = (e) => {
                // Chỉ drag khi click vào vùng trống, không phải reel card
                if (e.target.closest('.rls-c')) {
                    return; // Để reel card xử lý click để mở popup
                }
                
                isDraggingReel = true;
                measureReel();
                startXReel = getClientX(e);
                startTranslateReel = currentTranslateReel;
                reelSlider.classList.add('is-dragging');
                updateReelTransform(startTranslateReel, false);
                if (e.cancelable) e.preventDefault();
            };
            
            const onReelDragMove = (e) => {
                if (!isDraggingReel) return;
                const deltaX = getClientX(e) - startXReel;
                const newTranslate = startTranslateReel + deltaX;
                updateReelTransform(newTranslate, false);
                currentTranslateReel = newTranslate;
                if (e.cancelable) e.preventDefault();
            };
            
            const onReelDragEnd = (e) => {
                if (!isDraggingReel) return;
                isDraggingReel = false;
                reelSlider.classList.remove('is-dragging');
                
                const deltaX = currentTranslateReel - startTranslateReel;
                const threshold = reelWidth * 0.3;
                
                if (deltaX < -threshold) {
                    nextReel();
                } else if (deltaX > threshold) {
                    prevReel();
                } else {
                    goToReelIndex(currentReelIndex);
                }
            };
            
            // Desktop mouse events
            reelSlider.addEventListener('mousedown', onReelDragStart);
            window.addEventListener('mousemove', onReelDragMove);
            window.addEventListener('mouseup', onReelDragEnd);
            
            // Mobile touch events - swipe trái phải để chuyển reel
            let touchStartXReel = 0;
            let touchStartYReel = 0;
            let isTouchingReel = false;
            let touchMoved = false;
            
            reelSlider.addEventListener('touchstart', (e) => {
                console.log('Touch start');
                touchStartXReel = getClientX(e);
                touchStartYReel = e.touches[0].clientY;
                isTouchingReel = true;
                touchMoved = false;
            }, { passive: true });
            
            reelSlider.addEventListener('touchmove', (e) => {
                if (!isTouchingReel) return;
                
                const deltaX = getClientX(e) - touchStartXReel;
                const deltaY = e.touches[0].clientY - touchStartYReel;
                
                // Nếu có bất kỳ movement nào > 5px thì đánh dấu là đã move
                if (Math.abs(deltaX) > 5 || Math.abs(deltaY) > 5) {
                    touchMoved = true;
                }
                
                console.log('Touch move - deltaX:', deltaX, 'deltaY:', deltaY, 'touchMoved:', touchMoved);
                
                // Chỉ xử lý swipe ngang nếu di chuyển ngang nhiều hơn dọc
                if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 10) {
                    console.log('Horizontal swipe detected');
                    if (e.cancelable) e.preventDefault(); // Ngăn scroll dọc
                }
            }, { passive: false });
            
            reelSlider.addEventListener('touchend', (e) => {
                if (!isTouchingReel) return;
                
                const deltaX = e.changedTouches[0].clientX - touchStartXReel;
                const deltaY = e.changedTouches[0].clientY - touchStartYReel;
                const threshold = 50;
                
                console.log('Touch end - deltaX:', deltaX, 'deltaY:', deltaY, 'touchMoved:', touchMoved);
                
                // Nếu có movement đáng kể theo chiều ngang -> swipe carousel
                if (touchMoved && Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > threshold) {
                    if (deltaX < -threshold) {
                        console.log('Swipe left -> next');
                        nextReel();
                    } else if (deltaX > threshold) {
                        console.log('Swipe right -> prev');
                        prevReel();
                    }
                } else if (!touchMoved) {
                    // Chỉ mở popup nếu KHÔNG có movement (pure tap)
                    console.log('Pure tap detected - opening popup');
                    const reelCard = e.target.closest('.rls-c');
                    if (reelCard) {
                        const idx = parseInt(reelCard.getAttribute('data-reel-open') || '0', 10);
                        console.log('Opening popup for reel:', idx);
                        const event = new CustomEvent('openReelPopup', { detail: { index: idx } });
                        document.dispatchEvent(event);
                    }
                } else {
                    console.log('Movement detected but not enough for swipe - ignoring');
                }
                
                // Reset states
                isTouchingReel = false;
                touchMoved = false;
            });
            
            // Resize handler
            window.addEventListener('resize', () => {
                goToReelIndex(currentReelIndex, false);
            });
            
            // Initialize
            goToReelIndex(0, false);
        }
    }

    // Popup functionality
    const grid = document.querySelector('[data-fb-reels-grid]');
    const popup = document.getElementById('fb-reels-popup');
    
    if (!grid || !popup) {
        console.log('Grid or popup not found:', { grid, popup });
        return;
    }

    const popupTrack = popup.querySelector('[data-fb-popup-track]');
    const popupSlides = popupTrack ? Array.from(popupTrack.querySelectorAll('.fb-reels-popup-slide')) : [];
    const total = popupSlides.length;
    const counter = popup.querySelector('[data-fb-popup-counter]');
    const closeBtn = document.getElementById('fb-reels-popup-close');
    const prevBtn = document.getElementById('fb-reels-prev');
    const nextBtn = document.getElementById('fb-reels-next');

    console.log('=== Reel popup setup ===');
    console.log('Popup:', popup);
    console.log('Track:', popupTrack);
    console.log('Total slides:', total);
    console.log('Slides:', popupSlides);
    console.log('Close button:', closeBtn);
    console.log('Prev button:', prevBtn);
    console.log('Next button:', nextBtn);

    if (total === 0) {
        console.log('No slides found, exiting');
        return;
    }
    
    // Log all iframes
    popupSlides.forEach((slide, idx) => {
        const iframe = slide.querySelector('.fb-reels-popup-iframe');
        console.log(`Slide ${idx} iframe:`, iframe);
        if (iframe) {
            console.log(`  - data-src: ${iframe.dataset.src}`);
        }
    });

    let current = 0;
    let isOpen = false;
    let scrollY = 0;

    // --- Lazy load / unload iframe ---
    const loadSlide = (i) => {
        console.log('=== Loading slide:', i);
        const slide = popupSlides[i];
        if (!slide) {
            console.log('Slide not found at index:', i);
            return;
        }
        
        const iframe = slide.querySelector('.fb-reels-popup-iframe');
        
        if (iframe && !iframe.src && iframe.dataset.src) {
            console.log('Setting iframe src to:', iframe.dataset.src);
            iframe.src = iframe.dataset.src;
        }
    };

    const unloadSlide = (i) => {
        const slide = popupSlides[i];
        if (!slide) return;
        
        const iframe = slide.querySelector('.fb-reels-popup-iframe');
        if (iframe && iframe.src) {
            iframe.dataset.src = iframe.src;
            iframe.removeAttribute('src');
        }
    };

    // --- Track position ---
    const getTranslate = (i) => {
        // Mobile: chuyển ngang (translateX), Desktop: chuyển dọc (translateY)
        if (window.innerWidth <= 768) {
            return -(i * 100); // translateX percentage
        } else {
            return -(i * 100); // translateY percentage
        }
    };

    const goTo = (i, animated = true) => {
        const prev = current;
        current = Math.max(0, Math.min(total - 1, i));
        if (!popupTrack) return;
        
        popupTrack.style.transition = animated ? 'transform 0.4s cubic-bezier(0.16,1,0.3,1)' : 'none';
        
        // Mobile: chuyển ngang, Desktop: chuyển dọc
        if (window.innerWidth <= 768) {
            popupTrack.style.transform = `translateX(${getTranslate(current)}%)`;
        } else {
            popupTrack.style.transform = `translateY(${getTranslate(current)}vh)`;
        }
        
        if (counter) counter.textContent = `${current + 1} / ${total}`;
        if (prev !== current) unloadSlide(prev);
        loadSlide(current);
        if (prevBtn) prevBtn.style.opacity = current === 0 ? '0.3' : '1';
        if (nextBtn) nextBtn.style.opacity = current === total - 1 ? '0.3' : '1';
    };

    // --- iOS-safe scroll lock ---
    const lockScroll = () => {
        scrollY = window.scrollY;
        document.body.style.position = 'fixed';
        document.body.style.top = `-${scrollY}px`;
        document.body.style.width = '100%';
        document.body.style.overflow = 'hidden';
    };

    const unlockScroll = () => {
        document.body.style.position = '';
        document.body.style.top = '';
        document.body.style.width = '';
        document.body.style.overflow = '';
        window.scrollTo(0, scrollY);
    };

    const openPopup = (i) => {
        console.log('=== Opening popup for reel:', i);
        console.log('Total slides available:', total);
        
        isOpen = true;
        lockScroll();
        popup.style.display = 'flex'; // Force display flex
        popup.classList.add('is-open');
        popup.setAttribute('aria-hidden', 'false');
        
        console.log('Popup display:', popup.style.display);
        console.log('Popup classList:', popup.classList);
        
        // Force reflow để đảm bảo CSS được áp dụng
        popup.offsetHeight;
        
        // Load slide trước khi goTo
        console.log('About to load slide:', i);
        loadSlide(i);
        
        console.log('About to goTo:', i);
        goTo(i, false);
        
        console.log('Popup opened successfully, current slide:', i);
    };

    const closePopup = () => {
        console.log('Closing popup');
        isOpen = false;
        popup.style.display = 'none'; // Hide popup
        popup.classList.remove('is-open');
        popup.setAttribute('aria-hidden', 'true');
        unlockScroll();
        unloadSlide(current);
    };

    // --- Grid click ---
    grid.addEventListener('click', (e) => {
        console.log('Grid clicked:', e.target);
        const reelCard = e.target.closest('[data-reel-open]');
        if (!reelCard) {
            console.log('No reel card found');
            return;
        }
        const idx = parseInt(reelCard.getAttribute('data-reel-open') || '0', 10);
        console.log('Opening reel index:', idx);
        openPopup(idx);
    });
    
    // Listen for custom event from reel slider
    document.addEventListener('openReelPopup', (e) => {
        console.log('Custom event received:', e.detail);
        openPopup(e.detail.index);
    });

    // --- Close button ---
    if (closeBtn) closeBtn.addEventListener('click', closePopup);

    // --- Prev / Next (desktop) ---
    if (prevBtn) {
        prevBtn.addEventListener('click', (e) => {
            console.log('Prev button clicked');
            e.preventDefault();
            e.stopPropagation();
            goTo(current - 1);
        });
    }
    if (nextBtn) {
        nextBtn.addEventListener('click', (e) => {
            console.log('Next button clicked');
            e.preventDefault();
            e.stopPropagation();
            goTo(current + 1);
        });
    }

    // --- Keyboard ---
    document.addEventListener('keydown', (e) => {
        if (!isOpen) return;
        if (e.key === 'Escape') closePopup();
        if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') goTo(current - 1);
        if (e.key === 'ArrowDown' || e.key === 'ArrowRight') goTo(current + 1);
    });

    // --- Desktop: scroll wheel ---
    let wheelCooldown = false;
    popup.addEventListener('wheel', (e) => {
        if (!isOpen || wheelCooldown) return;
        e.preventDefault();
        wheelCooldown = true;
        setTimeout(() => { wheelCooldown = false; }, 600);
        if (e.deltaY > 0) goTo(current + 1);
        else goTo(current - 1);
    }, { passive: false });

    // --- Mobile: swipe left/right ---
    let touchStartX = 0;
    let touchStartY = 0;
    let touchLastX = 0;
    let touchLastY = 0;
    let touchStartTranslate = 0;
    let isTouching = false;

    const getClientX = (e) => e.touches ? e.touches[0].clientX : (e.changedTouches ? e.changedTouches[0].clientX : e.clientX);
    const getClientY = (e) => e.touches ? e.touches[0].clientY : (e.changedTouches ? e.changedTouches[0].clientY : e.clientY);

    popup.addEventListener('touchstart', (e) => {
        if (!isOpen) return;
        // Chỉ swipe khi chạm vào track, không phải iframe
        if (e.target.closest('iframe') || e.target.closest('.rls-x') || e.target.closest('.rls-pn')) return;
        
        isTouching = true;
        
        if (window.innerWidth <= 768) {
            // Mobile: horizontal swipe
            touchStartX = getClientX(e);
            touchLastX = touchStartX;
            touchStartTranslate = getTranslate(current);
        } else {
            // Desktop: vertical swipe
            touchStartY = getClientY(e);
            touchLastY = touchStartY;
            touchStartTranslate = getTranslate(current);
        }
        
        if (popupTrack) popupTrack.style.transition = 'none';
    }, { passive: true });

    popup.addEventListener('touchmove', (e) => {
        if (!isOpen || !isTouching) return;
        
        if (window.innerWidth <= 768) {
            // Mobile: horizontal movement
            touchLastX = getClientX(e);
            const delta = touchLastX - touchStartX;
            if (popupTrack) {
                popupTrack.style.transform = `translateX(calc(${touchStartTranslate}% + ${delta}px))`;
            }
        } else {
            // Desktop: vertical movement
            touchLastY = getClientY(e);
            const delta = touchLastY - touchStartY;
            if (popupTrack) {
                popupTrack.style.transform = `translateY(calc(${touchStartTranslate}vh + ${delta}px))`;
            }
        }
        
        if (e.cancelable) e.preventDefault();
    }, { passive: false });

    popup.addEventListener('touchend', () => {
        if (!isOpen || !isTouching) return;
        isTouching = false;
        
        const threshold = 60;
        
        if (window.innerWidth <= 768) {
            // Mobile: horizontal swipe
            const delta = touchLastX - touchStartX;
            if (delta < -threshold) goTo(current + 1); // Swipe left -> next
            else if (delta > threshold) goTo(current - 1); // Swipe right -> prev
            else goTo(current);
        } else {
            // Desktop: vertical swipe
            const delta = touchLastY - touchStartY;
            if (delta < -threshold) goTo(current + 1); // Swipe up -> next
            else if (delta > threshold) goTo(current - 1); // Swipe down -> prev
            else goTo(current);
        }
    });

    // --- Click backdrop ---
    popup.addEventListener('click', (e) => {
        if (e.target === popup) closePopup();
    });
})();


// ============================================
// YOUTUBE VIDEO LAZY LOAD
// Load video only when user clicks play button
// ============================================
(function() {
    console.log('YouTube lazy load script starting...');
    
    // Find all video containers
    const videoContainers = document.querySelectorAll('[data-video-container]');
    console.log('Found', videoContainers.length, 'video containers');
    
    videoContainers.forEach((container, index) => {
        const thumbnail = container.querySelector('.video-thumbnail');
        const playBtn = container.querySelector('.video-play-btn');
        
        console.log(`Container ${index}:`, {
            hasThumbnail: !!thumbnail,
            hasPlayBtn: !!playBtn,
            thumbnailSrc: thumbnail ? thumbnail.src : 'none',
            videoSrc: playBtn ? playBtn.getAttribute('data-video-src') : 'none'
        });
    });
    
    // Find all video play buttons
    const playButtons = document.querySelectorAll('.video-play-btn');
    
    console.log('Found', playButtons.length, 'video play buttons');
    
    playButtons.forEach((btn, index) => {
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Play button clicked for video', index);
            
            const videoSrc = this.getAttribute('data-video-src');
            const container = this.closest('[data-video-container]');
            
            if (!videoSrc || !container) {
                console.log('Missing video src or container');
                return;
            }
            
            console.log('Loading video:', videoSrc);
            
            // Create iframe
            const iframe = document.createElement('iframe');
            iframe.src = videoSrc + '?autoplay=1'; // Autoplay when loaded
            iframe.title = 'YouTube video player';
            iframe.frameBorder = '0';
            iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share';
            iframe.allowFullscreen = true;
            
            // Mark container as loaded
            container.classList.add('video-loaded');
            
            // Replace thumbnail with iframe
            container.innerHTML = '';
            container.appendChild(iframe);
            
            console.log('Video loaded successfully');
        });
    });
})();


// ===================================
// Feedback Form
// ===================================
(function() {
    const feedbackForm = document.getElementById('feedback-form');
    if (!feedbackForm) return;
    
    const textarea = document.getElementById('feedback-message');
    const charCurrent = document.getElementById('feedback-char-current');
    const submitBtn = feedbackForm.querySelector('.feedback-submit-btn');
    const btnText = submitBtn.querySelector('.feedback-btn-text');
    const btnLoading = submitBtn.querySelector('.feedback-btn-loading');
    const messageResult = document.getElementById('feedback-message-result');
    
    // Character counter
    textarea.addEventListener('input', function() {
        const length = this.value.length;
        charCurrent.textContent = length;
        
        if (length > 500) {
            this.value = this.value.substring(0, 500);
            charCurrent.textContent = 500;
        }
    });
    
    // Form submission
    feedbackForm.addEventListener('submit', function(e) {
        e.preventDefault();
        
        const message = textarea.value.trim();
        
        if (!message) {
            showMessage('Vui lòng nhập nội dung góp ý', 'error');
            return;
        }
        
        if (message.length > 500) {
            showMessage('Nội dung góp ý không được vượt quá 500 ký tự', 'error');
            return;
        }
        
        // Disable button and show loading
        submitBtn.disabled = true;
        btnText.style.display = 'none';
        btnLoading.style.display = 'flex';
        messageResult.style.display = 'none';
        
        // Send AJAX request
        const formData = new FormData();
        formData.append('action', 'submit_feedback');
        formData.append('nonce', aiQuestData.nonce);
        formData.append('message', message);
        
        fetch(aiQuestData.ajaxUrl, {
            method: 'POST',
            body: formData
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                showMessage('Cảm ơn bạn đã gửi góp ý! Chúng tôi sẽ xem xét và phản hồi sớm nhất.', 'success');
                textarea.value = '';
                charCurrent.textContent = '0';
            } else {
                showMessage(data.data || 'Có lỗi xảy ra. Vui lòng thử lại sau.', 'error');
            }
        })
        .catch(error => {
            console.error('Feedback submission error:', error);
            showMessage('Có lỗi xảy ra. Vui lòng thử lại sau.', 'error');
        })
        .finally(() => {
            // Re-enable button
            submitBtn.disabled = false;
            btnText.style.display = 'inline';
            btnLoading.style.display = 'none';
        });
    });
    
    function showMessage(text, type) {
        messageResult.textContent = text;
        messageResult.className = 'feedback-message-result ' + type;
        messageResult.style.display = 'block';
        
        // Auto hide after 5 seconds
        setTimeout(() => {
            messageResult.style.display = 'none';
        }, 5000);
    }
})();


// Lazy Loading Image Handler
(function() {
    // Handle ALL images on the page
    function handleAllImages() {
        const allImages = document.querySelectorAll('img');
        
        allImages.forEach(img => {
            // Skip if already handled
            if (img.classList.contains('loaded') || img.classList.contains('loading-handled')) {
                return;
            }
            
            img.classList.add('loading-handled');
            
            // Add loaded class when image loads
            if (img.complete && img.naturalHeight !== 0) {
                img.classList.add('loaded');
                img.style.opacity = '1';
            } else {
                img.addEventListener('load', function() {
                    this.classList.add('loaded');
                    this.style.opacity = '1';
                });
                
                img.addEventListener('error', function() {
                    this.classList.add('loaded');
                    this.style.opacity = '0.5';
                    console.warn('Image failed to load:', this.src);
                });
            }
        });
    }
    
    // Run on page load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', handleAllImages);
    } else {
        handleAllImages();
    }
    
    // Re-run when new images are added dynamically
    const observer = new MutationObserver(function(mutations) {
        let hasNewImages = false;
        mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeName === 'IMG' || (node.querySelectorAll && node.querySelectorAll('img').length > 0)) {
                    hasNewImages = true;
                }
            });
        });
        if (hasNewImages) {
            handleAllImages();
        }
    });
    
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
})();
