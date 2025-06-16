import Trie from 'substring-trie';

import { assetHost } from 'mastodon/utils/config';

import { autoPlayGif } from '../../initial_state';

import { unicodeMapping } from './emoji_unicode_mapping_light';

const trie = new Trie(Object.keys(unicodeMapping));

// Convert to file names from emojis. (For different variation selector emojis)
const emojiFilenames = (emojis) => {
  return emojis.map(v => unicodeMapping[v].filename);
};

// Emoji requiring extra borders depending on theme
const darkEmoji = emojiFilenames(['🎱', '🐜', '⚫', '🖤', '⬛', '◼️', '◾', '◼️', '✒️', '▪️', '💣', '🎳', '📷', '📸', '♣️', '🕶️', '✴️', '🔌', '💂‍♀️', '📽️', '🍳', '🦍', '💂', '🔪', '🕳️', '🕹️', '🕋', '🖊️', '🖋️', '💂‍♂️', '🎤', '🎓', '🎥', '🎼', '♠️', '🎩', '🦃', '📼', '📹', '🎮', '🐃', '🏴', '🐞', '🕺', '📱', '📲', '🚲', '🪮', '🐦‍⬛']);
const lightEmoji = emojiFilenames(['👽', '⚾', '🐔', '☁️', '💨', '🕊️', '👀', '🍥', '👻', '🐐', '❕', '❔', '⛸️', '🌩️', '🔊', '🔇', '📃', '🌧️', '🐏', '🍚', '🍙', '🐓', '🐑', '💀', '☠️', '🌨️', '🔉', '🔈', '💬', '💭', '🏐', '🏳️', '⚪', '⬜', '◽', '◻️', '▫️', '🪽', '🪿']);

/**
 * @param {string} filename
 * @param {"light" | "dark" } colorScheme
 * @returns {string}
 */
const emojiFilename = (filename, colorScheme) => {
  const borderedEmoji = colorScheme === "light" ? lightEmoji : darkEmoji;
  return borderedEmoji.includes(filename) ? (filename + '_border') : filename;
};

const emojifyTextNode = (node, customEmojis) => {
  const VS15 = 0xFE0E;
  const VS16 = 0xFE0F;

  let str = node.textContent;

  const fragment = new DocumentFragment();
  let i = 0;

  for (;;) {
    let unicode_emoji;

    // Skip to the next potential emoji to replace (either custom emoji or custom emoji :shortcode:
    if (customEmojis === null) {
      while (i < str.length && !(unicode_emoji = trie.search(str.slice(i)))) {
        i += str.codePointAt(i) < 65536 ? 1 : 2;
      }
    } else {
      while (i < str.length && str[i] !== ':' && !(unicode_emoji = trie.search(str.slice(i)))) {
        i += str.codePointAt(i) < 65536 ? 1 : 2;
      }
    }

    // We reached the end of the string, nothing to replace
    if (i === str.length) {
      break;
    }

    let rend, replacement = null;
    if (str[i] === ':') { // Potentially the start of a custom emoji :shortcode:
      rend = str.indexOf(':', i + 1) + 1;

      // no matching ending ':', skip
      if (!rend) {
        i++;
        continue;
      }

      const shortcode = str.slice(i, rend);
      const custom_emoji = customEmojis[shortcode];

      // not a recognized shortcode, skip
      if (!custom_emoji) {
        i++;
        continue;
      }

      // now got a replacee as ':shortcode:'
      // if you want additional emoji handler, add statements below which set replacement and return true.
      const filename = autoPlayGif ? custom_emoji.url : custom_emoji.static_url;
      replacement = document.createElement('img');
      replacement.setAttribute('draggable', 'false');
      replacement.setAttribute('class', 'emojione custom-emoji');
      replacement.setAttribute('alt', shortcode);
      replacement.setAttribute('title', shortcode);
      replacement.setAttribute('src', filename);
      replacement.setAttribute('data-original', custom_emoji.url);
      replacement.setAttribute('data-static', custom_emoji.static_url);
    } else { // start of an unicode emoji
      rend = i + unicode_emoji.length;

      // If the matched character was followed by VS15 (for selecting text presentation), skip it.
      if (str.codePointAt(rend - 1) !== VS16 && str.codePointAt(rend) === VS15) {
        i = rend + 1;
        continue;
      }

      const { filename, shortCode } = unicodeMapping[unicode_emoji];
      const title = shortCode ? `:${shortCode}:` : '';

      const isSystemTheme = !!document.body?.classList.contains('theme-system');

      const theme = (isSystemTheme || document.body?.classList.contains('theme-mastodon-light')) ? 'light' : 'dark';

      const imageFilename = emojiFilename(filename, theme);

      const img = document.createElement('img');
      img.setAttribute('draggable', 'false');
      img.setAttribute('class', 'emojione');
      img.setAttribute('alt', unicode_emoji);
      img.setAttribute('title', title);
      img.setAttribute('src', `${assetHost}/emoji/${imageFilename}.svg`);

      if (isSystemTheme && imageFilename !== emojiFilename(filename, 'dark')) {
        replacement = document.createElement('picture');

        const source = document.createElement('source');
        source.setAttribute('media', '(prefers-color-scheme: dark)');
        source.setAttribute('srcset', `${assetHost}/emoji/${emojiFilename(filename, 'dark')}.svg`);
        replacement.appendChild(source);
        replacement.appendChild(img);
      } else {
        replacement = img;
      }
    }

    // Add the processed-up-to-now string and the emoji replacement
    fragment.append(document.createTextNode(str.slice(0, i)));
    fragment.append(replacement);
    str = str.slice(rend);
    i = 0;
  }

  fragment.append(document.createTextNode(str));
  node.parentElement.replaceChild(fragment, node);
};

const emojifyNode = (node, customEmojis) => {
  for (const child of Array.from(node.childNodes)) {
    switch(child.nodeType) {
    case Node.TEXT_NODE:
      emojifyTextNode(child, customEmojis);
      break;
    case Node.ELEMENT_NODE:
      if (!child.classList.contains('invisible'))
        emojifyNode(child, customEmojis);
      break;
    }
  }
};

const emojify = (str, customEmojis = {}) => {
  const wrapper = document.createElement('div');
  wrapper.innerHTML = str;

  if (!Object.keys(customEmojis).length)
    customEmojis = null;

  emojifyNode(wrapper, customEmojis);

  return wrapper.innerHTML;
};

const emojify_astarte = (str, customEmojis = {}) => [
  {re: /5,?000\s*兆円/g, file: '5000tyoen.svg', attrs: 'style="height: 1.8em;"'},
  {re: /熱盛/g, file: 'atumori.svg', attrs: 'style="height: 2.5em;"'}, 
  {re: /バジリスク\s*タイム/g, file: 'basilisktime.svg', attrs: 'style="height: 2.5em;"'},
  {re: /欲しい！/g, file: 'hosii.svg', attrs: 'style="height: 1.7em;"'},
  {re: /ささやき(たいまー|タイマー)/g, file: 'in_to_the_dark.svg', attrs: 'class="astarte-stamp"'},
  {re: /:ロケット:/g, file: 'rocket.gif', attrs: 'class="astarte-stamp"'},
  {re: /:おはよう:/g, file: 'morning.gif', attrs: 'class="astarte-stamp"'},
  {re: /:かえりたい:/g, file: 'kaeritai.jpeg', attrs: 'class="astarte-stamp"'},
  {re: /:はらへり:/g, file: 'haraheri.png', attrs: 'class="astarte-stamp"'},
  {re: /:かなしい:/g, file: 'kanashi.png', attrs: 'class="astarte-stamp"'},
  {re: /:うれしい:/g, file: 'ureshi.png', attrs: 'class="astarte-stamp"'},
  {re: /:大喜利:/g, file: 'ogiri.jpeg', attrs: 'class="astarte-stamp"'},
  {re: /:ヘディング:/g, file: 'heading.gif', attrs: 'class="astarte-stamp"'},
  {re: /:ふたば_?おはよう:/g, file: 'hutaba.png', attrs: 'class="astarte-stamp"'},
  {re: /:じゃんけん:/g, file: 'janken.gif', attrs: 'class="astarte-stamp"'},
  {re: /:おやすみ:/g, file: 'good_night.gif', attrs: 'class="astarte-stamp"'},
  {re: /:ごはん:/g, file: 'gohan.png', attrs: 'class="astarte-stamp"'},
  {re: /:おそよう:/g, file: 'osoyou.png', attrs: 'class="astarte-stamp"'},
  {re: /:ありがとう:/g, file: 'arigatou.gif', attrs: 'class="astarte-stamp"'},
  {re: /:ルーレット:/g, file: 'roulette.gif', attrs: 'class="astarte-stamp"'},
  {re: /:働きたくない:/g, file: 'notWork.jpg', attrs: 'class="astarte-stamp"'},
  {re: /:起床Chance:/g, file: '750746c7bd3a0edc.png', attrs: 'class="astarte-stamp"'},
  {re: /:入眠Rush:/g, file: '80bff0490a51d517.png', attrs: 'class="astarte-stamp"'},
  {re: /:眠気襲来:/g, file: '45bec8a22a29e958.png', attrs: 'class="astarte-stamp"'},
  {re: /:みぷ:/g, file: 'd000e5d479ce618c.png', attrs: 'class="astarte-stamp"'},
  {re: /:全裸報告:/g, file: '2f18e130e4bfb19b.png', attrs: 'class="astarte-stamp"'},
  {re: /:NFC襲来:/g, file: '6537d027313fd066.png', attrs: 'class="astarte-stamp"'},
  {re: /:椅子転発生:/g, file: '889f2f40ede5d058.png', attrs: 'class="astarte-stamp"'},
].reduce((text, e) => text.replace(e.re, m => `<img alt="${m}" src="/emoji/${e.file}" ${e.attrs}/>`), emojify(str, customEmojis));

export default emojify_astarte;

export const buildCustomEmojis = (customEmojis) => {
  const emojis = [];

  customEmojis.forEach(emoji => {
    const shortcode = emoji.get('shortcode');
    const url       = autoPlayGif ? emoji.get('url') : emoji.get('static_url');
    const name      = shortcode.replace(':', '');

    emojis.push({
      id: name,
      name,
      short_names: [name],
      text: '',
      emoticons: [],
      keywords: [name],
      imageUrl: url,
      custom: true,
      customCategory: emoji.get('category'),
    });
  });

  return emojis;
};

export const categoriesFromEmojis = customEmojis => customEmojis.reduce((set, emoji) => set.add(emoji.get('category') ? `custom-${emoji.get('category')}` : 'custom'), new Set(['custom']));
