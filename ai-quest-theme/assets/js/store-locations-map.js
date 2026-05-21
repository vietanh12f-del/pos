(function () {
    const config = window.aiQuestStoreLocations;
    if (!config || !config.apiKey) return;

    const mapElementId = config.mapContainerId || 'aiq-store-map';
    const mapElement = document.getElementById(mapElementId);
    if (!mapElement) return;

    const escapeHtml = (value) => {
        return String(value ?? '').replace(/[&<>"']/g, (char) => {
            switch (char) {
                case '&':
                    return '&amp;';
                case '<':
                    return '&lt;';
                case '>':
                    return '&gt;';
                case '"':
                    return '&quot;';
                case "'":
                    return '&#039;';
                default:
                    return char;
            }
        });
    };

    const renderStars = (rating) => {
        const r = Number(rating);
        if (!Number.isFinite(r) || r <= 0) return '';
        const full = Math.max(0, Math.min(5, Math.floor(r)));
        const empty = 5 - full;
        return `${'★'.repeat(full)}${'☆'.repeat(empty)}`;
    };

    const buildInfoHtml = (place) => {
        const name = place?.name ? escapeHtml(place.name) : 'Địa điểm';
        const address = place?.formatted_address ? escapeHtml(place.formatted_address) : '';
        const rating = Number(place?.rating);
        const total = Number(place?.user_ratings_total);
        const stars = renderStars(rating);
        const ratingText = Number.isFinite(rating) ? rating.toFixed(1) : '';
        const totalText = Number.isFinite(total) ? `(${total.toLocaleString()} đánh giá)` : '';
        const url = place?.url ? escapeHtml(place.url) : '';

        const ratingLine = stars || ratingText || totalText
            ? `<div style="margin-top:6px; font-size:0.95rem; color:#111;">
                    <span style="color: var(--accent-spa); letter-spacing: 1px;">${stars}</span>
                    <span style="margin-left:8px; color:#111; font-weight:700;">${ratingText}</span>
                    <span style="margin-left:8px; color: var(--text-muted);">${escapeHtml(totalText)}</span>
               </div>`
            : '';

        const linkLine = url
            ? `<div style="margin-top:10px;">
                    <a href="${url}" target="_blank" rel="noopener" style="color: var(--primary-spa); text-decoration:none; font-weight:600;">Xem trên Google</a>
               </div>`
            : '';

        return `<div style="min-width:240px; max-width:320px; padding:2px 2px 4px 2px;">
                    <div style="font-weight:800; font-size:1.05rem; color:#111;">${name}</div>
                    ${address ? `<div style="margin-top:4px; font-size:0.9rem; color: var(--text-muted);">${address}</div>` : ''}
                    ${ratingLine}
                    ${linkLine}
                </div>`;
    };

    const ensureGoogleMaps = () => {
        if (window.google?.maps?.places) return Promise.resolve();
        if (window.__aiqMapsPromise) return window.__aiqMapsPromise;

        window.__aiqMapsPromise = new Promise((resolve, reject) => {
            const existing = document.querySelector('script[data-aiq-google-maps="1"]');
            if (existing) {
                existing.addEventListener('load', () => resolve());
                existing.addEventListener('error', () => reject(new Error('Google Maps script failed to load')));
                return;
            }

            const script = document.createElement('script');
            script.dataset.aiqGoogleMaps = '1';
            script.async = true;
            script.defer = true;
            const callbackName = 'aiQuestStoreLocationsInit';
            const params = new URLSearchParams({
                key: config.apiKey,
                libraries: 'places',
                callback: callbackName,
            });
            script.src = `https://maps.googleapis.com/maps/api/js?${params.toString()}`;
            script.onload = () => resolve();
            script.onerror = () => reject(new Error('Google Maps script failed to load'));
            document.head.appendChild(script);
        });

        return window.__aiqMapsPromise;
    };

    const getPlaceDetails = (service, placeId) => {
        return new Promise((resolve, reject) => {
            service.getDetails(
                {
                    placeId,
                    fields: ['place_id', 'name', 'formatted_address', 'rating', 'user_ratings_total', 'geometry', 'url'],
                },
                (place, status) => {
                    if (status === google.maps.places.PlacesServiceStatus.OK && place?.geometry?.location) {
                        resolve(place);
                        return;
                    }
                    reject(new Error(String(status)));
                }
            );
        });
    };

    const findPlaceByQuery = (service, query) => {
        return new Promise((resolve) => {
            service.findPlaceFromQuery(
                { query, fields: ['place_id', 'geometry'] },
                (results, status) => {
                    if (status === google.maps.places.PlacesServiceStatus.OK && Array.isArray(results) && results[0]?.place_id) {
                        resolve(results[0]);
                        return;
                    }
                    resolve(null);
                }
            );
        });
    };

    const geocodeAddress = (geocoder, address) => {
        return new Promise((resolve) => {
            geocoder.geocode({ address }, (results, status) => {
                if (status === 'OK' && Array.isArray(results) && results[0]?.geometry?.location) {
                    resolve(results[0]);
                    return;
                }
                resolve(null);
            });
        });
    };

    const initMap = async () => {
        const locations = Array.isArray(config.locations) ? config.locations : [];
        const usableLocations = locations.filter((l) => l && (l.placeId || l.address));
        if (!usableLocations.length) return;

        const map = new google.maps.Map(mapElement, {
            center: { lat: 10.7769, lng: 106.7009 },
            zoom: 12,
            mapTypeControl: false,
            fullscreenControl: false,
            streetViewControl: false,
        });

        const service = new google.maps.places.PlacesService(map);
        const geocoder = new google.maps.Geocoder();
        const infoWindow = new google.maps.InfoWindow();
        const bounds = new google.maps.LatLngBounds();

        for (const location of usableLocations) {
            let place = null;

            if (location.placeId) {
                try {
                    place = await getPlaceDetails(service, location.placeId);
                } catch (e) {
                    place = null;
                }
            }

            if (!place && location.address) {
                const found = await findPlaceByQuery(service, location.address);
                if (found?.place_id) {
                    try {
                        place = await getPlaceDetails(service, found.place_id);
                    } catch (e) {
                        place = null;
                    }
                }
            }

            if (!place && location.address) {
                const geo = await geocodeAddress(geocoder, location.address);
                if (geo?.geometry?.location) {
                    place = {
                        name: location.label || location.description || location.address,
                        formatted_address: location.address,
                        geometry: { location: geo.geometry.location },
                    };
                }
            }

            if (!place?.geometry?.location) continue;

            const marker = new google.maps.Marker({
                map,
                position: place.geometry.location,
                title: place.name || location.label || '',
            });

            marker.addListener('click', () => {
                infoWindow.setContent(buildInfoHtml(place));
                infoWindow.open(map, marker);
            });

            bounds.extend(place.geometry.location);
        }

        if (!bounds.isEmpty()) {
            map.fitBounds(bounds);
            google.maps.event.addListenerOnce(map, 'bounds_changed', () => {
                const z = map.getZoom();
                if (typeof z === 'number' && z > 16) map.setZoom(16);
            });
        }
    };

    window.aiQuestStoreLocationsInit = () => {
        if (window.__aiqStoreLocationsInitialized) return;
        window.__aiqStoreLocationsInitialized = true;
        initMap().catch(() => {});
    };

    ensureGoogleMaps()
        .then(() => {
            if (window.google?.maps) window.aiQuestStoreLocationsInit();
        })
        .catch(() => {});
})();

