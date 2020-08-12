import { autoPlayGif, useSystemEmojiFont } from 'flavours/glitch/util/initial_state';
import unicodeMapping from './emoji_unicode_mapping_light';
import Trie from 'substring-trie';

const trie = new Trie(Object.keys(unicodeMapping));

const assetHost = process.env.CDN_HOST || '';

// Convert to file names from emojis. (For different variation selector emojis)
const emojiFilenames = (emojis) => {
  return emojis.map(v => unicodeMapping[v].filename);
};

// Emoji requiring extra borders depending on theme
const darkEmoji = emojiFilenames(['🎱', '🐜', '⚫', '🖤', '⬛', '◼️', '◾', '◼️', '✒️', '▪️', '💣', '🎳', '📷', '📸', '♣️', '🕶️', '✴️', '🔌', '💂‍♀️', '📽️', '🍳', '🦍', '💂', '🔪', '🕳️', '🕹️', '🕋', '🖊️', '🖋️', '💂‍♂️', '🎤', '🎓', '🎥', '🎼', '♠️', '🎩', '🦃', '📼', '📹', '🎮', '🐃', '🏴']);
const lightEmoji = emojiFilenames(['👽', '⚾', '🐔', '☁️', '💨', '🕊️', '👀', '🍥', '👻', '🐐', '❕', '❔', '⛸️', '🌩️', '🔊', '🔇', '📃', '🌧️', '🐏', '🍚', '🍙', '🐓', '🐑', '💀', '☠️', '🌨️', '🔉', '🔈', '💬', '💭', '🏐', '🏳️', '⚪', '⬜', '◽', '◻️', '▫️']);

const emojiFilename = (filename) => {
  const borderedEmoji = (document.body && document.body.classList.contains('skin-mastodon-light')) ? lightEmoji : darkEmoji;
  return borderedEmoji.includes(filename) ? (filename + '_border') : filename;
};

const emojify = (str, customEmojis = {}) => {
  const tagCharsWithoutEmojis = '<&';
  const tagCharsWithEmojis = Object.keys(customEmojis).length ? '<&:' : '<&';
  let rtn = '', tagChars = tagCharsWithEmojis, invisible = 0;
  for (;;) {
    let match, i = 0, tag;
    while (i < str.length && (tag = tagChars.indexOf(str[i])) === -1 && (invisible || useSystemEmojiFont || !(match = trie.search(str.slice(i))))) {
      i += str.codePointAt(i) < 65536 ? 1 : 2;
    }
    let rend, replacement = '';
    if (i === str.length) {
      break;
    } else if (str[i] === ':') {
      if (!(() => {
        rend = str.indexOf(':', i + 1) + 1;
        if (!rend) return false; // no pair of ':'
        const lt = str.indexOf('<', i + 1);
        if (!(lt === -1 || lt >= rend)) return false; // tag appeared before closing ':'
        const shortname = str.slice(i, rend);
        // now got a replacee as ':shortname:'
        // if you want additional emoji handler, add statements below which set replacement and return true.
        if (shortname in customEmojis) {
          const filename = autoPlayGif ? customEmojis[shortname].url : customEmojis[shortname].static_url;
          replacement = `<img draggable="false" class="emojione custom-emoji" alt="${shortname}" title="${shortname}" src="${filename}" data-original="${customEmojis[shortname].url}" data-static="${customEmojis[shortname].static_url}" />`;
          return true;
        }
        return false;
      })()) rend = ++i;
    } else if (tag >= 0) { // <, &
      rend = str.indexOf('>;'[tag], i + 1) + 1;
      if (!rend) {
        break;
      }
      if (tag === 0) {
        if (invisible) {
          if (str[i + 1] === '/') { // closing tag
            if (!--invisible) {
              tagChars = tagCharsWithEmojis;
            }
          } else if (str[rend - 2] !== '/') { // opening tag
            invisible++;
          }
        } else {
          if (str.startsWith('<span class="invisible">', i)) {
            // avoid emojifying on invisible text
            invisible = 1;
            tagChars = tagCharsWithoutEmojis;
          }
        }
      }
      i = rend;
    } else if (!useSystemEmojiFont) { // matched to unicode emoji
      const { filename, shortCode } = unicodeMapping[match];
      const title = shortCode ? `:${shortCode}:` : '';
      replacement = `<img draggable="false" class="emojione" alt="${match}" title="${title}" src="${assetHost}/emoji/${emojiFilename(filename)}.svg" />`;
      rend = i + match.length;
      // If the matched character was followed by VS15 (for selecting text presentation), skip it.
      if (str.codePointAt(rend) === 65038) {
        rend += 1;
      }
    }
    rtn += str.slice(0, i) + replacement;
    str = str.slice(rend);
  }
  return rtn + str;
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

export { unicodeMapping };

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
