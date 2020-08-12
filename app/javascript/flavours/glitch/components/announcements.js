import React from 'react';
import Immutable from 'immutable';
import PropTypes from 'prop-types';
import { defineMessages, injectIntl } from 'react-intl';
import IconButton from './announcement_icon_button';
import Motion from 'react-motion/lib/Motion';
import spring from 'react-motion/lib/spring';

import Music from './music';

const Collapsable = ({ fullHeight, minHeight, isVisible, children }) => (
  <Motion defaultStyle={{ height: isVisible ? fullHeight : minHeight }} style={{ height: spring(!isVisible ? minHeight : fullHeight) }}>
    {({ height }) => (
      <div style={{ height: `${height}px`, overflow: 'hidden', width: '100%' }}>
        {children}
      </div>
    )}
  </Motion>
);

Collapsable.propTypes = {
  fullHeight: PropTypes.number.isRequired,
  minHeight: PropTypes.number.isRequired,
  isVisible: PropTypes.bool.isRequired,
  children: PropTypes.node.isRequired,
};

const messages = defineMessages({
  toggle_visible: { id: 'media_gallery.toggle_visible', defaultMessage: 'Toggle visibility' },
  welcome: { id: 'welcome.message', defaultMessage: '{domain}へようこそ!' },
  info: { id: 'info.list', defaultMessage: 'アスタルテについて' },
  donation: { id: 'donation.list', defaultMessage: '寄付について' },
  stamp: { id: 'stamp.list', defaultMessage: 'スタンプ一覧' },
  bbcode: { id: 'bbcode.list', defaultMessage: 'BBCode一覧' },
  markdown: { id: 'markdown.list', defaultMessage: 'markdown一覧' },
});

const hashtags = Immutable.fromJS([
  '神崎ドン自己紹介',
]);

class Announcements extends React.PureComponent {

  static propTypes = {
    intl: PropTypes.object.isRequired,
    homeSize: PropTypes.number,
    isLoading: PropTypes.bool,
  };

  state = {
    showId: null,
    isLoaded: false,
  };

  onClick = (announcementId, currentState) => {
    this.setState({ showId: currentState.showId === announcementId ? null : announcementId });
  }

  nl2br (text) {
    return text.split(/(\n)/g).map((line, i) => {
      if (line.match(/(\n)/g)) {
        return React.createElement('br', { key: i });
      }
      return line;
    });
  }

  render () {
    const { intl } = this.props;

    return (
      <ul className='announcements__astarte'>
        <li>
          <Collapsable isVisible={this.state.showId === 'info'} fullHeight={360} minHeight={20} >
            <div className='announcements__atarte__body'>
              <p>{ this.nl2br(intl.formatMessage(messages.info, { domain: document.title }))}<br />
                <br />
			  アスタルテと関連のサービス<br />
                <br />
			  ・MINECRAFT Server(停止中)<br />
			  [address] mc.kirishima.cloud <br />
			  [URL] http://mc.kirishima.cloud:8123 <br />
                <a href='http://mc.kirishima.cloud:8123' target='_blank'>マップを開く</a><br /><br />
        ・Cutlsさんのサービス<br />
        TheDeskはCutlsさんが製作している<br />アスタルテの公認クライアントです<br />
                <a href='https://thedesk.top/' target='_blank'>TheDeskホームページ</a><br /><br />
        暇人ランキング<br />
        暇人ランキングはアスタルテの投稿数で<br />ランキング付けされてます<br />
                <a href='https://astarte.thedesk.top/' target='_blank'>暇ラン</a>
                <br />
              </p>
            </div>
          </Collapsable>
          <div className='announcements__astarte__icon'>
            <IconButton title={intl.formatMessage(messages.toggle_visible)} icon='caret-up' onClick={() => this.onClick('info', this.state)} size={20} animate active={this.state.showId === 'info'} />
          </div>
        </li>
        <li>
          <Collapsable isVisible={this.state.showId === 'donation'} fullHeight={270} minHeight={20} >
            <div className='announcements__astarte__body'>
              <p>{ this.nl2br(intl.formatMessage(messages.donation, { domain: document.title }))}<br />
                <br />
			  ・欲しいものリスト<br />
			  [URL] http://amzn.asia/hJLmEbc <br />
                <a href='http://amzn.asia/hJLmEbc' target='_blank'>欲しいものリストを開く</a><br />
        ・FanBox <br />
			  [URL] https://www.pixiv.net/fanbox/creator/13015144 <br />
                <a href='https://www.pixiv.net/fanbox/creator/13015144' target='_blank'>FanBoxのページを開く</a><br />
			  寄付していただいた場合<br />
			  お名前を寄付一覧に載せます。<br />
			  強制ではありませんのでDMでご連絡ください<br />
              </p>
            </div>
          </Collapsable>
          <div className='announcements__astarte__icon'>
            <IconButton title={intl.formatMessage(messages.toggle_visible)} icon='caret-up' onClick={() => this.onClick('donation', this.state)} size={20} animate active={this.state.showId === 'donation'} />
          </div>
        </li>
        <li>
          <Collapsable isVisible={this.state.showId === 'stamp'} fullHeight={580} minHeight={22} >
            <div className='announcements__astarte__body'>
              <p>{ this.nl2br(intl.formatMessage(messages.stamp, { domain: document.title }))}<br />
                <br />
                  5000兆円<br />
                  欲しい！<br />
                  熱盛<br />
                  バジリスクタイム<br />
                  ささやきタイマー<br />
                  :おはよう:<br />
                  :かえりたい:<br />
                  :はらへり:<br />
                  :うれしい:<br />
                  :かなしい:<br />
                  :ロケット:<br />
                  :ヘディング:<br />
                  :ふたば_おはよう:(_は入力しなくても可)<br />
                  :じゃんけん:<br />
                  :おやすみ:<br />
                  :ごはん:<br />
                  :おそよう:<br />
                  :ありがとう:<br />
                  :ルーレット:<br />
                  :大喜利:<br />
                  :働きたくない:<br />
                  :起床Chance:<br />
                  :入眠Rush:<br />
                  :眠気襲来:<br />
                  :MySweetHomeAstarte:<br />
                  :全裸報告:<br />
                  :NFC襲来:<br />
                  :椅子転発生:<br />
              </p>
            </div>
          </Collapsable>
          <div className='announcements__astarte__icon'>
            <IconButton title={intl.formatMessage(messages.toggle_visible)} icon='caret-up' onClick={() => this.onClick('stamp', this.state)} size={20} animate active={this.state.showId === 'stamp'} />
          </div>
        </li>
        <li>
          <Collapsable isVisible={this.state.showId === 'bbcode'} fullHeight={380} minHeight={20} >
            <div className='announcements__astarte__body'>
              <p>{ this.nl2br(intl.formatMessage(messages.bbcode, { domain: document.title }))}<br />
                <br />
			  [spin]回転[/spin]<br />
			  [pulse]点滅[/pulse]<br />
			  [large=2x]倍角文字[/large]<br />
			  [flip=vertical]縦反転[/flip]<br />
			  [flip=horizontal]横反転[/flip]<br />
        [rotatez=45]右に45°回転[/rotatez]<br />
        [marq=lateral]横移動[/marq]<br />
			  [b]太字[/b]<br />
			  [i]斜体[/i]<br />
			  [u]アンダーライン[/u]<br />
			  [s]取り消し線[/s]<br />
			  [colorhex=A55A4A]色変更02[/colorhex]<br />
			  [code]コード[/code]<br />
			  [quote]引用[/quote]<br />
        [youtube]動画ID[/youtube]<br />
        [faicon]coffee[/faicon](<span class='fa fa-coffee' />の例)<br />
                <a href='https://yuzulabo.github.io/generate-faicon/' target='_blank'>faiconを生成</a>
                <a href='https://fontawesome.com/v4.7.0/icons/' target='_blank'>faicon アイコン一覧</a><br /><br />
              </p>
            </div>
          </Collapsable>
          <div className='announcements__astarte__icon'>
            <IconButton title={intl.formatMessage(messages.toggle_visible)} icon='caret-up' onClick={() => this.onClick('bbcode', this.state)} size={20} animate active={this.state.showId === 'bbcode'} />
          </div>
        </li>
        <li>
          <Collapsable isVisible={this.state.showId === 'markdown'} fullHeight={1240} minHeight={20} >
            <div className='announcements__astarte__body'>
              <p>{ this.nl2br(intl.formatMessage(messages.markdown, { domain: document.title }))}<br /><br />
                (半角)は半角スペースを入力する必要がある場所です。(半角)だけの列は半角スペースのみが入力された列が必要であるを指します。<br /><br />
                〜〜〜〜〜〜見出し〜〜〜〜〜〜<br /><br />
                #(半角)見出しテキスト<br /><br />
                #は1〜6個重ねることができます。<br /><br />
                〜〜〜〜コードブロック〜〜〜〜<br /><br />
                `コード`<br /><br />
                〜〜〜〜〜〜引用〜〜〜〜〜〜<br /><br />
                &gt;引用文<br />
                (半角)<br />
                ここから先は引用が切れます<br />
                引用は複数回重ねることが可能です。<br /><br />
                〜〜〜〜〜〜リスト〜〜〜〜〜〜<br /><br />
                (半角)<br />
                +(半角)内容1<br />
                +(半角)内容2<br />
                (半角)<br /><br />
                内容の数に制限はありません。<br />
                投稿トップにリストを持ってくる場合に限り1行目の(半角)は必要ありません。<br />
                +(半角)を1.(半角)に置き換えることで数字付きリストになります。<br /><br />
                〜〜〜〜〜上付き文字〜〜〜〜〜<br /><br />
                _上付き文字_<br /><br />
                〜〜〜〜〜下付き文字〜〜〜〜〜<br /><br />
                __下付き文字__<br /><br />
                〜〜〜〜〜小さい文字〜〜〜〜〜<br /><br />
                ___小さい文字___<br /><br />
                〜〜〜〜〜取り消し線〜〜〜〜〜<br /><br />
                ~~取り消したい文字列~~<br /><br />
                〜〜〜〜〜〜横罫線〜〜〜〜〜〜<br /><br />
                ___<br /><br />
                〜〜〜〜〜〜リンク〜〜〜〜〜〜<br /><br />
                [リンク文章](https://・・・)<br /><br />
                〜〜〜〜〜〜画像〜〜〜〜〜〜<br /><br />
                ![画像説明](https://・・・)<br /><br />
                リンク、画像ともにURLにはhttps://から始まる物のみご利用可能です。
              </p>
            </div>
          </Collapsable>
          <div className='announcements__astarte__icon'>
            <IconButton title={intl.formatMessage(messages.toggle_visible)} icon='caret-up' onClick={() => this.onClick('markdown', this.state)} size={20} animate active={this.state.showId === 'markdown'} />
          </div>
        </li>
        <li>
          <Collapsable isVisible={this.state.showId === 'music'} fullHeight={410} minHeight={22} >
            <div className='announcements__astarte__body'>
              <Music />
            </div>
          </Collapsable>
          <div className='announcements__astarte__icon'>
            <IconButton title={intl.formatMessage(messages.toggle_visible)} icon='caret-up' onClick={() => this.onClick('music', this.state)} size={20} animate active={this.state.showId === 'music'} />
          </div>
        </li>
      </ul>
    );
  }

  componentWillReceiveProps (nextProps) {
    if (!this.state.isLoaded) {
      if (!nextProps.isLoading && (nextProps.homeSize === 0 || this.props.homeSize !== nextProps.homeSize)) {
        this.setState({ isLoaded: true });
      }
    }
  }

}

export default injectIntl(Announcements);
